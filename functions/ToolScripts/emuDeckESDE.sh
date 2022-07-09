#!/bin/bash
#variables
ESDE_toolName="EmulationStation-DE"
ESDE_toolType="AppImage"
ESDE_toolPath="${toolsPath}EmulationStation-DE-x64_SteamDeck.AppImage"
ESDE_releaseURL="https://gitlab.com/es-de/emulationstation-de/-/raw/master/es-app/assets/latest_steam_deck_appimage.txt"

es_systemsFile="$HOME/.emulationstation/custom_systems/es_systems.xml"
es_settingsFile="$HOME/.emulationstation/es_settings.xml"

#cleanupOlderThings
ESDE.cleanup(){
	echo "NYI"
}

#Install
ESDE.install(){
	setMSG "Installing $ESDE_toolName"		

    curl $ESDE_releaseURL --output "$toolsPath"latesturl.txt 
    latestURL=$(grep "https://gitlab" "$toolsPath"latesturl.txt)

    curl $latestURL --output $ESDE_toolPath
    rm "$toolsPath"/latesturl.txt
    chmod +x $ESDE_toolPath	
	
}

#ApplyInitialSettings
ESDE.init(){

	setMSG "Setting up $ESDE_toolName"	

	mkdir -p "$HOME/.emulationstation/custom_systems/"

	rsync -avhp --mkpath "$EMUDECKGIT/configs/emulationstation/es_settings.xml" "$es_settingsFile" --backup --suffix=.bak
	rsync -avhp --mkpath "$EMUDECKGIT/configs/emulationstation/custom_systems/es_systems.xml" "$es_systemsFile" --backup --suffix=.bak

    ESDE.addCustomSystems
    ESDE.setEmulationFolder
    ESDE.setDefaultEmulators
    ESDE.applyTheme "EPICNOIR"
    ESDE.migrateDownloadedMedia
    ESDE.finalize
}



ESDE.update(){


	setMSG "Setting up $ESDE_toolName"	

	mkdir -p "$HOME/.emulationstation/custom_systems/"

	#update es_settings.xml
	rsync -avhp --mkpath "$EMUDECKGIT/configs/emulationstation/es_settings.xml" "$es_settingsFile" --ignore-existing
	rsync -avhp --mkpath "$EMUDECKGIT/configs/emulationstation/custom_systems/es_systems.xml" "$es_systemsFile" --ignore-existing

    ESDE.addCustomSystems
	ESDE.setEmulationFolder
    ESDE.setDefaultEmulators
    ESDE.applyTheme "EPICNOIR"
    ESDE.migrateDownloadedMedia
    ESDE.finalize
}

ESDE.addCustomSystems(){


	#insert cemu custom system if it doesn't exist, but the file does
	if [[ $(grep -rnw $es_systemsFile -e 'Cemu (Proton)') == "" ]]; then
		xmlstarlet ed --inplace --subnode '/systemList' --type elem --name 'system' \
		--var newSystem '$prev' \
		--subnode '$newSystem' --type elem --name 'name' -v 'wiiu' \
		--subnode '$newSystem' --type elem --name 'fullname' -v 'Nintendo Wii U' \
		--subnode '$newSystem' --type elem --name 'path' -v '%ROMPATH%/wiiu/roms' \
		--subnode '$newSystem' --type elem --name 'extension' -v '.rpx .RPX .wud .WUD .wux .WUX .elf .ELF .iso .ISO .wad .WAD .wua .WUA' \
		--subnode '$newSystem' --type elem --name 'command' -v "/usr/bin/bash ${toolsPath}launchers/cemu.sh -f -g z:%ROM%" \
		--insert '$newSystem/command' --type attr --name 'label' --value "Cemu (Proton)" \
		--subnode '$newSystem' --type elem --name 'platform' -v 'wiiu' \
		--subnode '$newSystem' --type elem --name 'theme' -v 'wiiu' \
		$es_systemsFile
	fi
	#Custom Systems config end


}

#update
ESDE.applyTheme(){
    defaultTheme="MODERN-DE"
    esdeTheme=$1
    if [[ "${esdeTheme}" == "" ]]; then
        echo "ESDE: applyTheme parameter not set."
        esdeTheme="$defaultTheme"
    fi
    echo "ESDE: applyTheme $esdeTheme"
    mkdir -p "$HOME/.emulationstation/themes/"
	git clone https://github.com/dragoonDorise/es-theme-epicnoir.git "$HOME/.emulationstation/themes/es-epicnoir" &>> /dev/null
	cd "$HOME/.emulationstation/themes/es-epicnoir" && git pull
	echo -e "OK!"
	
	if [[ "$esdeTheme" == *"EPICNOIR"* ]]; then
		changeLine '<string name="ThemeSet"' '<string name="ThemeSet" value="es-epicnoir" />' $es_settingsFile 
	fi
	if [[ "$esdeTheme" == *"MODERN-DE"* ]]; then
        changeLine '<string name="ThemeSet"' '<string name="ThemeSet" value="modern-DE" />' $es_settingsFile 
	fi
	if [[ "$esdeTheme" == *"RBSIMPLE-DE"* ]]; then
        changeLine '<string name="ThemeSet"' '<string name="ThemeSet" value="rbsimple-DE" />' $es_settingsFile 
	fi
}

#ConfigurePaths
ESDE.setEmulationFolder(){

    #update cemu custom system launcher to correct path by just replacing the line, if it exists.
	commandString="/usr/bin/bash ${toolsPath}launchers/cemu.sh -f -g z:%ROM%"
	xmlstarlet ed -L -u '/systemList/system/command[@label="Cemu (Proton)"]' -v "$commandString" $es_systemsFile

	#configure roms Directory
	esDE_romDir="<string name=\"ROMDirectory\" value=\""${romsPath}"\" />"
	changeLine '<string name="ROMDirectory"' "${esDE_romDir}" $es_settingsFile

	
	#Configure Downloaded_media folder
	esDE_MediaDir="<string name=\"MediaDirectory\" value=\""${ESDEscrapData}"\" />"
	#search for media dir in xml, if not found, change to ours. If it's blank, also change to ours.
	mediaDirFound=$(grep -rnw  $es_settingsFile -e 'MediaDirectory')
	mediaDirEmpty=$(grep -rnw  $es_settingsFile -e '<string name="MediaDirectory" value="" />')
	if [[ $mediaDirFound == '' ]]; then
		sed -i -e '$a'"${esDE_MediaDir}"  $es_settingsFile # use config file instead of link
	elif [[ ! $mediaDirEmpty == '' ]]; then
		changeLine '<string name="MediaDirectory"' "${esDE_MediaDir}" $es_settingsFile
	fi
}

ESDE.setDefaultEmulators(){
	#ESDE default emulators
	mkdir -p  "$HOME/.emulationstation/gamelists/"
	setESDEEmus 'Dolphin (Standalone)' gc
	setESDEEmus 'PPSSPP (Standalone)' psp
	setESDEEmus 'Dolphin (Standalone)' wii
	setESDEEmus 'PCSX2 (Standalone)' ps2
	setESDEEmus 'melonDS' nds
	setESDEEmus 'Citra (Standalone)' n3ds
}


ESDE.migrateDownloadedMedia(){

    echo "ESDE: Migrate Downloaded Media."

    originalESMediaFolder="$HOME/.emulationstation/downloaded_media"
    echo "processing $originalESMediaFolder"
    if [ -L ${originalESMediaFolder} ] ; then
        echo "link found"
        unlink ${originalESMediaFolder} && echo "unlinked"
    elif [ -e ${originalESMediaFolder} ] ; then
        if [ -d "${originalESMediaFolder}" ]; then		
            echo -e ""
            echo -e "Moving EmulationStation-DE downloaded_media to $toolsPath"			
            echo -e ""
            rsync -a $originalESMediaFolder $toolsPath  && rm -rf $originalESMediaFolder		#move it, merging files if in both locations
        fi
    else
        echo "downloaded_media not found on original location"
    fi
}

#finalExec - Extra stuff
ESDE.finalize(){
   	#Symlinks for ESDE compatibility
	cd $(echo $romsPath | tr -d '\r') 
	ln -sn gamecube gc 
	ln -sn 3ds n3ds 
	ln -sn arcade mamecurrent 
	ln -sn mame mame2003 
	ln -sn lynx atarilynx 
}