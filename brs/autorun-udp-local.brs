' customized to add /GetUDPEvents to the new local web server'
Library "autoplugins.brs"

'region Main
Sub Main()

    autorunVersion$ = "6.7.13" ' BA 3.7.0.13
    customAutorunVersion$ = "6.7.0"

    debugParams = EnableDebugging()
	
    sysFlags = CreateObject("roAssociativeArray")
    sysFlags.debugOn = debugParams.serialDebugOn    
	sysFlags.systemLogDebugOn = debugParams.systemLogDebugOn
    
    modelObject = CreateObject("roDeviceInfo")
    sysInfo = CreateObject("roAssociativeArray")
    sysInfo.autorunVersion$ = autorunVersion$
    sysInfo.customAutorunVersion$ = customAutorunVersion$
    sysInfo.deviceUniqueID$ = modelObject.GetDeviceUniqueId()
    sysInfo.deviceFWVersion$ = modelObject.GetVersion()
    sysInfo.deviceModel$ = modelObject.GetModel()
    sysInfo.deviceFamily$ = modelObject.GetFamily()
    sysInfo.enableLogDeletion = true

	sysInfo.ipAddressWired$ = "Invalid"
	nc = CreateObject("roNetworkConfiguration", 0)
	if type(nc) = "roNetworkConfiguration" then
        currentConfig = nc.GetCurrentConfig()
        if type(currentConfig) = "roAssociativeArray" then
			if currentConfig.ip4_address <> "" then
				sysInfo.ipAddressWired$ = currentConfig.ip4_address
			endif
        endif
	endif
	nc = invalid

    sysInfo.modelSupportsWifi = false
	sysInfo.ipAddressWireless$ = "Invalid"
    nc = CreateObject("roNetworkConfiguration", 1)
    if type(nc) = "roNetworkConfiguration" then
        currentConfig = nc.GetCurrentConfig()
        if type(currentConfig) = "roAssociativeArray" then
            sysInfo.modelSupportsWifi = true
			if currentConfig.ip4_address <> "" then
				sysInfo.ipAddressWireless$ = currentConfig.ip4_address
			endif
        endif
    endif
    nc = invalid

	sysInfo.modelSupportsRoAudioOutput = false
	if not (sysInfo.deviceFamily$ = "monaco" or sysInfo.deviceFamily$ = "pandora3" or sysInfo.deviceFamily$ = "apollo" or sysInfo.deviceFamily$ = "bpollo") then 
		sysInfo.modelSupportsRoAudioOutput = true
		videoMode = CreateObject("roVideoMode")
		edid = videoMode.GetEdidIdentity(true)
		UpdateEdidValues(edid, sysInfo)
		edid = invalid
		videoMode = invalid
	else
		UpdateEdidValues(invalid, sysInfo)
	endif

' check to see whether or not the current firmware meets the minimum compatibility requirements
	versionNumber% = modelObject.GetVersionNumber()

	if sysInfo.deviceFamily$ = "panther" then
		minVersionNumber% = 263717
		minVersion$ = "4.6.37"
	else if sysInfo.deviceFamily$ = "cheetah" then
		minVersionNumber% = 263717
		minVersion$ = "4.6.37"
	else if sysInfo.deviceFamily$ = "puma" then
		minVersionNumber% = 263717
		minVersion$ = "4.6.37"
	else
		minVersionNumber% = 199203
		minVersion$ = "3.10.35"
	endif

	if versionNumber% < minVersionNumber% then
        videoMode = CreateObject("roVideoMode")
        resX = videoMode.GetResX()
        resY = videoMode.GetResY()
        videoMode = invalid
        r=CreateObject("roRectangle",0,resY/2-resY/64,resX,resY/32)
        twParams = CreateObject("roAssociativeArray")
        twParams.LineCount = 1
        twParams.TextMode = 2
        twParams.Rotation = 0
        twParams.Alignment = 1
        tw=CreateObject("roTextWidget",r,1,2,twParams)
        tw.PushString("Firmware needs to be upgraded to " + minVersion$ + " or greater")
        tw.Show()
		sleep(120000)
        RebootSystem()
	endif
	
	' determine if the storage device is writable
	tmpFileName$ = "bs~69-96.txt"
	WriteAsciiFile(tmpFileName$, "1")
    readValue$ = ReadAsciiFile(tmpFileName$)
	if len(readValue$) = 1 and readValue$ = "1" then
		sysInfo.storageIsWriteProtected = false
		DeleteFile(tmpFileName$)
	else
		sysInfo.storageIsWriteProtected = true
	endif

    diagnosticCodes = newDiagnosticCodes()
    
    RunBsp(sysFlags, sysInfo, diagnosticCodes)
    
End Sub


Sub UpdateEdidValues(edid As Object, sysInfo As Object)

	if type(edid) = "roAssociativeArray" then
		sysInfo.edidMonitorSerialNumber$ = edid.serial_number_string
		sysInfo.edidYearOfManufacture$ = edid.year_of_manufacture
		sysInfo.edidMonitorName$ = edid.monitor_name
		sysInfo.edidManufacturer$ = edid.manufacturer
		sysInfo.edidUnspecifiedText$ = edid.text_string
		sysInfo.edidSerialNumber$ = StripLeadingSpaces(stri(edid.serial_number))
		sysInfo.edidManufacturerProductCode$ = edid.product
		sysInfo.edidWeekOfManufacture$ = edid.week_of_manufacture
	else
		sysInfo.edidMonitorSerialNumber$ = ""
		sysInfo.edidYearOfManufacture$ = ""
		sysInfo.edidMonitorName$ = ""
		sysInfo.edidManufacturer$ = ""
		sysInfo.edidUnspecifiedText$ = ""
		sysInfo.edidSerialNumber$ = ""
		sysInfo.edidManufacturerProductCode$ = ""
		sysInfo.edidWeekOfManufacture$ = ""
	endif

End Sub


Sub DisplayErrorScreen(msg1$ As String, msg2$ As String)

	videoMode = CreateObject("roVideoMode")
	resX = videoMode.GetResX()
	resY = videoMode.GetResY()
	videoMode = invalid

	r = CreateObject("roRectangle", 0, 0, resX, resY)
	twParams = CreateObject("roAssociativeArray")
	twParams.LineCount = 1
	twParams.TextMode = 2
	twParams.Rotation = 0
	twParams.Alignment = 1
	tw=CreateObject("roTextWidget",r,1,2,twParams)
	tw.PushString("")
	tw.Show()

	r=CreateObject("roRectangle",0,resY/2-resY/32,resX,resY/32)
	tw=CreateObject("roTextWidget",r,1,2,twParams)
	tw.PushString(msg1$)
	tw.Show()

	r2=CreateObject("roRectangle",0,resY/2,resX,resY/32)
	tw2=CreateObject("roTextWidget",r2,1,2,twParams)
	tw2.PushString(msg2$)
	tw2.Show()

    msgPort = CreateObject("roMessagePort")
    msg = wait(0, msgPort)

End Sub


Sub DisplayStorageDeviceLockedMessage()
	DisplayErrorScreen("The attached storage device is write protected.", "Remove it, enable writing, and reboot the device.")
End Sub


Sub DisplayIncompatibleModelMessage(publishedModel$ As String, currentModel$ As String)
	DisplayErrorScreen("This presentation targets a BrightSign " + publishedModel$ + " and won't play on a " + currentModel$ + ".", "Remove the card, publish a compatible presentation, and reboot the device.")
End Sub


Function EnableDebugging() As Object

	debugParams = CreateObject("roAssociativeArray")
	
	debugParams.serialDebugOn = false
	debugParams.systemLogDebugOn = false
	
	networkedCurrentSync = CreateObject("roSyncSpec")
	if networkedCurrentSync.ReadFromFile("current-sync.xml") then
		if networkedCurrentSync.LookupMetadata("client", "enableSerialDebugging") = "True" then
			debugParams.serialDebugOn = true
		endif
		if networkedCurrentSync.LookupMetadata("client", "enableSystemLogDebugging") = "True" then
			debugParams.systemLogDebugOn = true
		endif
	else
		localCurrentSync = CreateObject("roSyncSpec")
		if localCurrentSync.ReadFromFile("local-sync.xml") then
			if localCurrentSync.LookupMetadata("client", "enableSerialDebugging") = "True" then
				debugParams.serialDebugOn = true
			endif
			if localCurrentSync.LookupMetadata("client", "enableSystemLogDebugging") = "True" then
				debugParams.systemLogDebugOn = true
			endif
		endif
		localCurrentSync = invalid
	endif
	networkedCurrentSync = invalid
	
	return debugParams
	
End Function


Sub WriteRegistrySetting(key$ As String, value$ As String)
	
	m.registrySection.Write(key$, value$)

End Sub


Function GetRegistrySettingValue(newRegistryKey$ As String, oldRegistryKey$ As String) As String
    
    value$ = m.registrySection.Read(newRegistryKey$)
    if value$ = "" then
        value$ = m.registrySection.Read(oldRegistryKey$)
    endif
    return value$

End Function


Sub ReadCachedRegistrySettings()

	m.registrySettings = CreateObject("roAssociativeArray")
	
    m.registrySettings.lwsConfig$ = m.registrySection.Read("nlws")
    m.registrySettings.lwsUserName$ = m.registrySection.Read("nlwsu")
    m.registrySettings.lwsPassword$ = m.registrySection.Read("nlwsp")        

    m.registrySettings.unitName$ = m.GetRegistrySettingValue("un", "unitName")
    m.registrySettings.unitNamingMethod$ = m.GetRegistrySettingValue("unm", "unitNamingMethod")
    m.registrySettings.unitDescription$ = m.GetRegistrySettingValue("ud", "unitDescription")
	
	m.registrySettings.playbackLoggingEnabled = m.registrySection.Read("ple")
	m.registrySettings.eventLoggingEnabled = m.registrySection.Read("ele")
	m.registrySettings.diagnosticLoggingEnabled = m.registrySection.Read("dle")
	m.registrySettings.stateLoggingEnabled = m.registrySection.Read("sle")
	m.registrySettings.uploadLogFilesAtBoot = m.registrySection.Read("uab")
	m.registrySettings.uploadLogFilesAtSpecificTime = m.registrySection.Read("uat")
	m.registrySettings.uploadLogFilesTime$ = m.registrySection.Read("ut")

	m.registrySettings.OnlyDownloadIfCached$ = m.registrySection.Read("OnlyDownloadIfCached")

    m.registrySettings.timeBetweenNetConnects$ = m.GetRegistrySettingValue("tbnc", "timeBetweenNetConnects")
    m.registrySettings.contentDownloadsRestricted = m.GetRegistrySettingValue("cdr", "contentDownloadsRestricted")
    m.registrySettings.contentDownloadRangeStart = m.GetRegistrySettingValue("cdrs", "contentDownloadRangeStart")
    m.registrySettings.contentDownloadRangeLength = m.GetRegistrySettingValue("cdrl", "contentDownloadRangeLength")

    m.registrySettings.timeBetweenHeartbeats$ = m.GetRegistrySettingValue("tbh", "tbh")
    m.registrySettings.heartbeatsRestricted = m.GetRegistrySettingValue("hr", "hr")
    m.registrySettings.heartbeatsRangeStart = m.GetRegistrySettingValue("hrs", "hrs")
    m.registrySettings.heartbeatsRangeLength = m.GetRegistrySettingValue("hdrl", "hrl")

	m.registrySettings.rateLimitModeOutsideWindow$ = m.registrySection.Read("rlmow")
	m.registrySettings.rateLimitRateOutsideWindow$ = m.registrySection.Read("rlrow")
	m.registrySettings.rateLimitModeInWindow$ = m.registrySection.Read("rlmiw")
	m.registrySettings.rateLimitRateInWindow$ = m.registrySection.Read("rlriw")

    m.registrySettings.tbnco$ = m.registrySection.Read("tbnco")

    m.registrySettings.useWireless$ = m.registrySection.Read("wifi")
    m.registrySettings.ssid$ = m.registrySection.Read("ss")
    m.registrySettings.passphrase$ = m.registrySection.Read("pp")
    m.registrySettings.timeServer$ = m.GetRegistrySettingValue("ts", "timeServer")

	m.registrySettings.wiredNetworkingParameters = {}
	m.registrySettings.wiredNetworkingParameters.networkConnectionPriority$ = m.registrySection.Read("ncp")

	m.registrySettings.wirelessNetworkingParameters = {}
	m.registrySettings.wirelessNetworkingParameters.networkConnectionPriority$ = m.registrySection.Read("ncp2")

	if m.registrySettings.useWireless$ = "yes" then
		m.registrySettings.wirelessNetworkingParameters.useDHCP$ = m.registrySection.Read("dhcp")
		m.registrySettings.wirelessNetworkingParameters.staticIPAddress$ = m.registrySection.Read("sip")
		m.registrySettings.wirelessNetworkingParameters.subnetMask$ = m.registrySection.Read("sm")
		m.registrySettings.wirelessNetworkingParameters.gateway$ = m.registrySection.Read("gw")
		m.registrySettings.wirelessNetworkingParameters.dns1$ = m.registrySection.Read("d1")
		m.registrySettings.wirelessNetworkingParameters.dns2$ = m.registrySection.Read("d2")
		m.registrySettings.wirelessNetworkingParameters.dns3$ = m.registrySection.Read("d3")

		m.registrySettings.wiredNetworkingParameters.useDHCP$ = m.registrySection.Read("dhcp2")
		m.registrySettings.wiredNetworkingParameters.staticIPAddress$ = m.registrySection.Read("sip2")
		m.registrySettings.wiredNetworkingParameters.subnetMask$ = m.registrySection.Read("sm2")
		m.registrySettings.wiredNetworkingParameters.gateway$ = m.registrySection.Read("gw2")
		m.registrySettings.wiredNetworkingParameters.dns1$ = m.registrySection.Read("d12")
		m.registrySettings.wiredNetworkingParameters.dns2$ = m.registrySection.Read("d22")
		m.registrySettings.wiredNetworkingParameters.dns3$ = m.registrySection.Read("d32")
	else
		m.registrySettings.wiredNetworkingParameters.useDHCP$ = m.registrySection.Read("dhcp")
		m.registrySettings.wiredNetworkingParameters.staticIPAddress$ = m.registrySection.Read("sip")
		m.registrySettings.wiredNetworkingParameters.subnetMask$ = m.registrySection.Read("sm")
		m.registrySettings.wiredNetworkingParameters.gateway$ = m.registrySection.Read("gw")
		m.registrySettings.wiredNetworkingParameters.dns1$ = m.registrySection.Read("d1")
		m.registrySettings.wiredNetworkingParameters.dns2$ = m.registrySection.Read("d2")
		m.registrySettings.wiredNetworkingParameters.dns3$ = m.registrySection.Read("d3")
	endif

	m.registrySettings.contentXfersEnabledWired$ = m.registrySection.Read("cwr")
	m.registrySettings.textFeedsXfersEnabledWired$ = m.registrySection.Read("twr")
	m.registrySettings.healthXfersEnabledWired$ = m.registrySection.Read("hwr")
	m.registrySettings.mediaFeedsXfersEnabledWired$ = m.registrySection.Read("mwr")
	m.registrySettings.logUploadsXfersEnabledWired$ = m.registrySection.Read("lwr")
    
	m.registrySettings.contentXfersEnabledWireless$ = m.registrySection.Read("cwf")
	m.registrySettings.textFeedsXfersEnabledWireless$ = m.registrySection.Read("twf")
	m.registrySettings.healthXfersEnabledWireless$ = m.registrySection.Read("hwf")
	m.registrySettings.mediaFeedsXfersEnabledWireless$ = m.registrySection.Read("mwf")
	m.registrySettings.logUploadsXfersEnabledWireless$ = m.registrySection.Read("lwf")

    m.registrySettings.logDate$ = m.registrySection.Read("ld")
    m.registrySettings.logCounter$ = m.registrySection.Read("lc")

    m.registrySettings.dwsEnabled$ = m.registrySection.Read("dwse")
    m.registrySettings.dwsPassword$ = m.registrySection.Read("dwsp")

	m.registrySettings.usbContentUpdatePassword$ = m.registrySection.Read("uup")

End Sub


Sub RunBsp(sysFlags As Object, sysInfo As Object, diagnosticCodes As Object)

    msgPort = CreateObject("roMessagePort")
    
    BSP = newBSP(sysFlags, msgPort)
		
	BSP.GetRegistrySettingValue = GetRegistrySettingValue
	BSP.ReadCachedRegistrySettings = ReadCachedRegistrySettings
	BSP.WriteRegistrySetting = WriteRegistrySetting
	BSP.ReadCachedRegistrySettings()
	
    BSP.globalVariables = NewGlobalVariables()

	BSP.controlPort = CreateObject("roControlPort", "BrightSign")
    BSP.controlPort.SetPort(msgPort)

	BSP.sh = CreateObject("roStorageHotplug")
    BSP.sh.SetPort(msgPort)

	BSP.nh = CreateObject("roNetworkHotplug")
	BSP.nh.SetPort(msgPort)

	BSP.videoMode = CreateObject("roVideoMode")
	BSP.videoMode.SetPort(msgPort)

' create objects for lighting controllers
	BSP.blcs = CreateObject("roArray", 3, true)
	BSP.blcs[0] = CreateObject("roControlPort", "LightController-0-CONTROL")
	BSP.blcs[1] = CreateObject("roControlPort", "LightController-1-CONTROL")
	BSP.blcs[2] = CreateObject("roControlPort", "LightController-2-CONTROL")

' create objects for blc diagnostics
	BSP.blcDiagnostics = CreateObject("roArray", 3, true)
	
	BSP.blcDiagnostics[0] = CreateObject("roControlPort", "LightController-0-DIAGNOSTICS")
	if type(BSP.blcDiagnostics[0]) = "roControlPort" then
		BSP.blcDiagnostics[0].SetPort(msgPort)
	endif

	BSP.blcDiagnostics[1] = CreateObject("roControlPort", "LightController-1-DIAGNOSTICS")
	if type(BSP.blcDiagnostics[1]) = "roControlPort" then
		BSP.blcDiagnostics[1].SetPort(msgPort)
	endif

	BSP.blcDiagnostics[2] = CreateObject("roControlPort", "LightController-2-DIAGNOSTICS")
	if type(BSP.blcDiagnostics[2]) = "roControlPort" then
		BSP.blcDiagnostics[2].SetPort(msgPort)
	endif

' create objects for all attached button panels

	BSP.bpInputPorts = CreateObject("roArray", 3, true)
	BSP.bpInputPortIdentities = CreateObject("roArray", 3, true)
	BSP.bpInputPortHardware = CreateObject("roArray", 3, true)
	BSP.bpInputPortConfigurations = CreateObject("roArray", 3, true)

	BSP.bpInputPorts[0] = CreateObject("roControlPort", "TouchBoard-0-GPIO")
	if type(BSP.bpInputPorts[0]) = "roControlPort" then
		BSP.bpInputPortIdentities[0] = stri(BSP.bpInputPorts[0].GetIdentity())
	    BSP.bpInputPorts[0].SetPort(msgPort)
		properties = BSP.bpInputPorts[0].GetProperties()
		BSP.bpInputPortHardware[0] = properties.hardware
		BSP.bpInputPortConfigurations[0] = 0
    endif
    
	BSP.bpInputPorts[1] = CreateObject("roControlPort", "TouchBoard-1-GPIO")
	if type(BSP.bpInputPorts[1]) = "roControlPort" then
		BSP.bpInputPortIdentities[1] = stri(BSP.bpInputPorts[1].GetIdentity())	
	    BSP.bpInputPorts[1].SetPort(msgPort)
		properties = BSP.bpInputPorts[1].GetProperties()
		BSP.bpInputPortHardware[1] = properties.hardware
		BSP.bpInputPortConfigurations[1] = 0
    endif
    
	BSP.bpInputPorts[2] = CreateObject("roControlPort", "TouchBoard-2-GPIO")
	if type(BSP.bpInputPorts[2]) = "roControlPort" then
		BSP.bpInputPortIdentities[2] = stri(BSP.bpInputPorts[2].GetIdentity())	
	    BSP.bpInputPorts[2].SetPort(msgPort)
		properties = BSP.bpInputPorts[2].GetProperties()
		BSP.bpInputPortHardware[2] = properties.hardware
		BSP.bpInputPortConfigurations[2] = 0
    endif
    
    BSP.sysInfo = sysInfo
    BSP.diagnosticCodes = diagnosticCodes

    BSP.diagnostics.SetSystemInfo(sysInfo, diagnosticCodes)
    BSP.logging.SetSystemInfo(sysInfo, diagnosticCodes)

	' if the device is configured for local file networking with content transfers, require that the storage is writable
	if BSP.registrySettings.lwsConfig$ = "c" and BSP.sysInfo.storageIsWriteProtected then DisplayStorageDeviceLockedMessage()

    if BSP.registrySettings.lwsConfig$ = "c" or BSP.registrySettings.lwsConfig$ = "s" then

		lwsUserName$ = BSP.registrySettings.lwsUserName$
		lwsPassword$ = BSP.registrySettings.lwsPassword$
        
        if (len(lwsUserName$) + len(lwsPassword$)) > 0 then
            credentials = CreateObject("roAssociativeArray")
            credentials.AddReplace(lwsUserName$, lwsPassword$)
        else
            credentials = invalid
        end if
                        
        BSP.localServer = CreateObject("roHttpServer", { port: 8080 })
        BSP.localServer.SetPort(msgPort)

        BSP.GetIDAA =               { HandleEvent: GetID, mVar: BSP }
        BSP.GetUDPEventsAA =        { HandleEvent: GetUDPEvents, mVar: BSP }
        BSP.GetRemoteDataAA =       { HandleEvent: GetRemoteData, mVar: BSP }
		BSP.GetUserVarsAA =         { HandleEvent: GetUserVars, mVar: BSP }
        BSP.GetCurrentStatusAA =    { HandleEvent: GetCurrentStatus, mVar: BSP }
        BSP.FilePostedAA =          { HandleEvent: FilePosted, mVar: BSP }
        BSP.SyncSpecPostedAA =      { HandleEvent: SyncSpecPosted, mVar: BSP }
        BSP.PrepareForTransferAA =  { HandleEvent: PrepareForTransfer, mVar: BSP }

		BSP.SendUdpRestAA =			{ HandleEvent: SendUdpRest, mVar: BSP }

		BSP.localServer.AddGetFromFile({ url_path: "/GetAutorun", content_type: "text/plain; charset=utf-8", filename: "autorun.brs"})

        BSP.localServer.AddGetFromEvent({ url_path: "/GetID", user_data: BSP.GetIDAA })
        BSP.localServer.AddGetFromEvent({ url_path: "/GetUDPEvents", user_data: BSP.GetUDPEventsAA })
        BSP.localServer.AddGetFromEvent({ url_path: "/GetRemoteData", user_data: BSP.GetRemoteDataAA })
		BSP.localServer.AddGetFromEvent({ url_path: "/GetUserVars", user_data: BSP.GetUserVarsAA})
        BSP.localServer.AddGetFromEvent({ url_path: "/GetCurrentStatus", user_data: BSP.GetCurrentStatusAA, passwords: credentials })        

        BSP.localServer.AddPostToFile({ url_path: "/UploadFile", destination_directory: GetDefaultDrive(), user_data: BSP.FilePostedAA, passwords: credentials })
        BSP.localServer.AddPostToFile({ url_path: "/UploadSyncSpec", destination_directory: GetDefaultDrive(), user_data: BSP.SyncSpecPostedAA, passwords: credentials })
        BSP.localServer.AddPostToFile({ url_path: "/PrepareForTransfer", destination_directory: GetDefaultDrive(), user_data: BSP.PrepareForTransferAA, passwords: credentials })
	
		BSP.localServer.AddPostToFormData({ url_path: "/SendUDP", user_data: BSP.SendUdpRestAA })

        unitName$ = BSP.registrySettings.unitName$
        unitNamingMethod$ = BSP.registrySettings.unitNamingMethod$
        unitDescription$ = BSP.registrySettings.unitDescription$
        
        if BSP.registrySettings.lwsConfig$ = "c" then
            BSP.lwsConfig$ = "content"
        else
            BSP.lwsConfig$ = "status"
        endif
        
        service = { name: "BrightSign Web Service", type: "_http._tcp", port: 8080, _functionality: BSP.lwsConfig$, _serialNumber: sysInfo.deviceUniqueID$, _unitName: unitName$, _unitNamingMethod: unitNamingMethod$, _unitDescription: unitDescription$ }
        BSP.advert = CreateObject("roNetworkAdvertisement", service)
        if BSP.advert = invalid then
            stop
        end if
    
    else
    
        BSP.lwsConfig$ = "none"
    
	endif
	
    BSP.syncPoolFiles = invalid
    localCurrentSync = CreateObject("roSyncSpec")
    if localCurrentSync.ReadFromFile("local-sync.xml") then
        BSP.syncPoolFiles = CreateObject("roSyncPoolFiles", "pool", localCurrentSync)

		' update registry setting for USB content updates if necessary
		metadata = localCurrentSync.GetMetadata("client")
		if metadata.DoesExist("usbUpdatePassword") then
			usbUpdatePassphrase$ = localCurrentSync.LookupMetadata("client", "usbUpdatePassword")

			if usbUpdatePassphrase$ <> BSP.registrySettings.usbContentUpdatePassword$ then
				BSP.registrySettings.usbContentUpdatePassword$ = usbUpdatePassphrase$
				BSP.WriteRegistrySetting("uup", usbUpdatePassphrase$)
			endif
		endif

    endif

' networking is considered active if current-sync.xml is present.
    networkedCurrentSyncValid = false
	networkedCurrentSync = CreateObject("roSyncSpec")
	
	if networkedCurrentSync.ReadFromFile("current-sync.xml") then
	
		' if the device is configured for networking, require that the storage is writable
		if BSP.sysInfo.storageIsWriteProtected then DisplayStorageDeviceLockedMessage()

        networkedCurrentSyncValid = true

		BSP.contentXfersEnabledWired = GetDataTransferEnabled(networkedCurrentSync, "contentXfersEnabledWired")
		BSP.textFeedsXfersEnabledWired = GetDataTransferEnabled(networkedCurrentSync, "textFeedsXfersEnabledWired")
		BSP.healthXfersEnabledWired = GetDataTransferEnabled(networkedCurrentSync, "healthXfersEnabledWired")
		BSP.mediaFeedsXfersEnabledWired = GetDataTransferEnabled(networkedCurrentSync, "mediaFeedsXfersEnabledWired")
		BSP.logUploadsXfersEnabledWired = GetDataTransferEnabled(networkedCurrentSync, "logUploadsXfersEnabledWired")
    
		BSP.contentXfersEnabledWireless = GetDataTransferEnabled(networkedCurrentSync, "contentXfersEnabledWireless")
		BSP.textFeedsXfersEnabledWireless = GetDataTransferEnabled(networkedCurrentSync, "textFeedsXfersEnabledWireless")
		BSP.healthXfersEnabledWireless = GetDataTransferEnabled(networkedCurrentSync, "healthXfersEnabledWireless")
		BSP.mediaFeedsXfersEnabledWireless = GetDataTransferEnabled(networkedCurrentSync, "mediaFeedsXfersEnabledWireless")
		BSP.logUploadsXfersEnabledWireless = GetDataTransferEnabled(networkedCurrentSync, "logUploadsXfersEnabledWireless")
    
		BSP.networkingHSM = newNetworkingStateMachine(BSP, BSP.msgPort)
		
		BSP.networkingHSM.SetSystemInfo(sysInfo, diagnosticCodes)
		BSP.logging.networking = BSP.networkingHSM

        BSP.syncPoolFiles = CreateObject("roSyncPoolFiles", "pool", networkedCurrentSync)
        BSP.downloadFiles = networkedCurrentSync.GetFileList("download")
        
		BSP.networkingActive = true
		
		BSP.networkingHSM.Initialize()
			
    else
    
		BSP.networkingHSM = invalid
		
        BSP.networkingActive = false
        
    endif

' determine and set file paths for global files
	globalAA = GetGlobalAA()
    globalAA.autoscheduleFilePath$ = GetPoolFilePath(BSP.syncPoolFiles, "autoschedule.xml")
    globalAA.resourcesFilePath$ = GetPoolFilePath(BSP.syncPoolFiles, "resources.txt")
    globalAA.boseProductsFilePath$ = GetPoolFilePath(BSP.syncPoolFiles, "BoseProducts.xml")
    if globalAA.autoscheduleFilePath$ = "" then stop
    
' initialize logging parameters
    playbackLoggingEnabled = false
    eventLoggingEnabled = false
    diagnosticLoggingEnabled = false
    stateLoggingEnabled = false
    uploadLogFilesAtBoot = false
    uploadLogFilesAtSpecificTime = false
    uploadLogFilesTime% = 0

    if networkedCurrentSyncValid then
        if networkedCurrentSync.LookupMetadata("client", "playbackLoggingEnabled") = "yes" then playbackLoggingEnabled = true
        if networkedCurrentSync.LookupMetadata("client", "eventLoggingEnabled") = "yes" then eventLoggingEnabled = true
        if networkedCurrentSync.LookupMetadata("client", "diagnosticLoggingEnabled") = "yes" then diagnosticLoggingEnabled = true
        if networkedCurrentSync.LookupMetadata("client", "stateLoggingEnabled") = "yes" then stateLoggingEnabled = true
        if networkedCurrentSync.LookupMetadata("client", "uploadLogFilesAtBoot") = "yes" then uploadLogFilesAtBoot = true
        if networkedCurrentSync.LookupMetadata("client", "uploadLogFilesAtSpecificTime") = "yes" then uploadLogFilesAtSpecificTime = true
        uploadLogFilesTime$ = networkedCurrentSync.LookupMetadata("client", "uploadLogFilesTime")

	' as of BrightAuthor 3.0, logging parameters are set when the user performs a standalone publish - no uploads for a standalone unit, so leave those values false
	else if type(localCurrentSync) = "roSyncSpec" then
        
		if localCurrentSync.LookupMetadata("client", "playbackLoggingEnabled") = "yes" then
			playbackLoggingEnabled = true
		else if localCurrentSync.LookupMetadata("client", "playbackLoggingEnabled") = "no" then
			playbackLoggingEnabled = false
        else if BSP.registrySettings.playbackLoggingEnabled = "yes" then
			playbackLoggingEnabled = true
		endif

		if localCurrentSync.LookupMetadata("client", "eventLoggingEnabled") = "yes" then
			eventLoggingEnabled = true
		else if localCurrentSync.LookupMetadata("client", "eventLoggingEnabled") = "no" then
			eventLoggingEnabled = false
        else if BSP.registrySettings.eventLoggingEnabled = "yes" then
			eventLoggingEnabled = true
		endif

		if localCurrentSync.LookupMetadata("client", "diagnosticLoggingEnabled") = "yes" then
			diagnosticLoggingEnabled = true
		else if localCurrentSync.LookupMetadata("client", "diagnosticLoggingEnabled") = "no" then
			diagnosticLoggingEnabled = false
        else if BSP.registrySettings.diagnosticLoggingEnabled = "yes" then
			diagnosticLoggingEnabled = true
		endif

		if localCurrentSync.LookupMetadata("client", "stateLoggingEnabled") = "yes" then
			stateLoggingEnabled = true
		else if localCurrentSync.LookupMetadata("client", "stateLoggingEnabled") = "no" then
			stateLoggingEnabled = false
        else if BSP.registrySettings.stateLoggingEnabled = "yes" then
			stateLoggingEnabled = true
		endif

		uploadLogFilesTime$ = ""

		BSP.GetDataTransferEnabledFromRegistry = GetDataTransferEnabledFromRegistry

		BSP.contentXfersEnabledWired = BSP.GetDataTransferEnabledFromRegistry("contentXfersEnabledWired$")
		BSP.textFeedsXfersEnabledWired = BSP.GetDataTransferEnabledFromRegistry("textFeedsXfersEnabledWired$")
		BSP.healthXfersEnabledWired = BSP.GetDataTransferEnabledFromRegistry("healthXfersEnabledWired$")
		BSP.mediaFeedsXfersEnabledWired = BSP.GetDataTransferEnabledFromRegistry("mediaFeedsXfersEnabledWired$")
		BSP.logUploadsXfersEnabledWired = BSP.GetDataTransferEnabledFromRegistry("logUploadsXfersEnabledWired$")

		BSP.contentXfersEnabledWireless = BSP.GetDataTransferEnabledFromRegistry("contentXfersEnabledWireless$")
		BSP.textFeedsXfersEnabledWireless = BSP.GetDataTransferEnabledFromRegistry("textFeedsXfersEnabledWireless$")
		BSP.healthXfersEnabledWireless = BSP.GetDataTransferEnabledFromRegistry("healthXfersEnabledWireless$")
		BSP.mediaFeedsXfersEnabledWireless = BSP.GetDataTransferEnabledFromRegistry("mediaFeedsXfersEnabledWireless$")
		BSP.logUploadsXfersEnabledWireless = BSP.GetDataTransferEnabledFromRegistry("logUploadsXfersEnabledWireless$")

	else
        if BSP.registrySettings.playbackLoggingEnabled = "yes" then playbackLoggingEnabled = true
        if BSP.registrySettings.eventLoggingEnabled = "yes" then eventLoggingEnabled = true
        if BSP.registrySettings.stateLoggingEnabled = "yes" then stateLoggingEnabled = true
        if BSP.registrySettings.diagnosticLoggingEnabled = "yes" then diagnosticLoggingEnabled = true
        if BSP.registrySettings.uploadLogFilesAtBoot = "yes" then uploadLogFilesAtBoot = true
        if BSP.registrySettings.uploadLogFilesAtSpecificTime = "yes" then uploadLogFilesAtSpecificTime = true
        uploadLogFilesTime$ = BSP.registrySettings.uploadLogFilesTime$
    endif
    if uploadLogFilesTime$ <> "" then uploadLogFilesTime% = int(val(uploadLogFilesTime$))
    
' if the device is configured for logging, require that the storage is writable
	if (playbackLoggingEnabled or eventLoggingEnabled or stateLoggingEnabled or diagnosticLoggingEnabled) and BSP.sysInfo.storageIsWriteProtected then DisplayStorageDeviceLockedMessage()

' setup logging
    BSP.logging.InitializeLogging(playbackLoggingEnabled, eventLoggingEnabled, stateLoggingEnabled, diagnosticLoggingEnabled, uploadLogFilesAtBoot, uploadLogFilesAtSpecificTime, uploadLogFilesTime%)
    
    BSP.logging.WriteDiagnosticLogEntry(diagnosticCodes.EVENT_STARTUP, BSP.sysInfo.deviceFWVersion$ + chr(9) + BSP.sysInfo.autorunVersion$ + chr(9) + BSP.sysInfo.customAutorunVersion$)
        
    BSP.InitializeNonPrintableKeyboardCodeList()

' Read and parse BoseProducts.xml
	BSP.boseProductSpecs = ReadBoseProductsFile()

' Get tuner data
	BSP.scannedChannels = GetScannedChannels()

' BP state machines and associated data structures
	dim bpStateMachineRequired[3,11]
	dim bpInputUsed[3,11]
	dim bpOutputUsed[3,11]
	dim bpSM[3,11]
	
	BSP.bpStateMachineRequired = bpStateMachineRequired
	BSP.bpInputUsed = bpInputUsed
	BSP.bpOutputUsed = bpOutputUsed
	BSP.bpSM = bpSM

' Create state machines

	' Player state machine
	BSP.playerHSM = newPlayerStateMachine(BSP)
	BSP.playerHSM.SetSystemInfo(sysInfo, diagnosticCodes)
	
	' Zone state machines are created by the Player state machine when it parses the schedule and autoplay files
    BSP.playerHSM.Initialize()
    
	BSP.CheckBLCsStatus()

    BSP.EventLoop()
    
End Sub


Sub CheckBLCsStatus()

	CheckBLCStatus(m.blcs[0], 0)
	CheckBLCStatus(m.blcs[1], 0)
	CheckBLCStatus(m.blcs[2], 0)

End Sub


Sub CheckBLCStatus(controlPort As Object, channel% As Integer)

	if type(controlPort) <> "roControlPort" return

	control_cmd = CreateObject("roArray", 4, false)

	CHANNEL_CMD_STATUS%    = &h1700

	control_cmd[ 0 ] = CHANNEL_CMD_STATUS%
	control_cmd[ 1 ] = channel%				' Channel to check status for (note use 0 for main power)
	control_cmd[ 2 ] = 0                    ' unused
	control_cmd[ 3 ] = 0                    ' unused

	controlPort.SetOutputValues(control_cmd)

End Sub


Function GetDataTransferEnabled(syncSpec As Object, syncSpecEntry$ As String) As Boolean

	spec$ = syncSpec.LookupMetadata("client", syncSpecEntry$)
	dataTransferEnabled = true
	if lcase(spec$) = "false" then dataTransferEnabled = false
	return dataTransferEnabled

End Function


Function GetDataTransferEnabledFromRegistry(registryKey$ As String) As Boolean

	if m.registrySettings.Lookup(registryKey$) = "False" then
		registryValue = false
	else
		registryValue = true
	endif

	return registryValue

End Function


Function GetBinding(wiredTransferEnabled As Boolean, wirelessTransferEnabled As Boolean) As Integer

	binding% = -1
	if wiredTransferEnabled <> wirelessTransferEnabled then
		if wiredTransferEnabled then
			binding% = 0
		else
			binding% = 1
		endif
	endif

	return binding%

End Function


Function newBSP(sysFlags As Object, msgPort As Object) As Object

    BSP = CreateObject("roAssociativeArray")

    registrySection = CreateObject("roRegistrySection", "networking")
    if type(registrySection)<>"roRegistrySection" then print "Error: Unable to create roRegistrySection":stop
    BSP.registrySection = registrySection
    
    BSP.msgPort = msgPort

    BSP.systemTime = CreateObject("roSystemTime")

    BSP.diagnostics = newDiagnostics(sysFlags)

    BSP.Restart = Restart
    BSP.StartPlayback = StartPlayback

	BSP.ClearImageBuffers = ClearImageBuffers
	
    BSP.newLogging = newLogging
    BSP.logging = BSP.newLogging()
	BSP.LogActivePresentation = LogActivePresentation

    BSP.SetTouchRegions = SetTouchRegions
    BSP.InitializeTouchScreen = InitializeTouchScreen
    BSP.AddRectangularTouchRegion = AddRectangularTouchRegion

	BSP.TuneToChannel = TuneToChannel
	BSP.SendTuneFailureMessage = SendTuneFailureMessage

    BSP.ExecuteMediaStateCommands = ExecuteMediaStateCommands
    BSP.ExecuteTransitionCommands = ExecuteTransitionCommands
    BSP.ExecuteCmd = ExecuteCmd
	BSP.ExecuteSwitchPresentationCommand = ExecuteSwitchPresentationCommand
	BSP.ChangeRFChannel = ChangeRFChannel

    BSP.EventLoop = EventLoop

    BSP.StopSignChannel = StopSignChannel

    BSP.MapDigitalOutput = MapDigitalOutput
    BSP.SetAudioOutput = SetAudioOutput
    BSP.SetAudioMode = SetAudioMode
    BSP.MapStereoOutput = MapStereoOutput
    BSP.SetSpdifMute = SetSpdifMute
    BSP.SetAnalogMute = SetAnalogMute
    BSP.SetHDMIMute = SetHDMIMute
    
	BSP.UnmuteAllAudio = UnmuteAllAudio
	BSP.UnmuteAudioConnector = UnmuteAudioConnector
	BSP.SetAllAudioOutputs = SetAllAudioOutputs
	BSP.SetAudioMode1 = SetAudioMode1
	BSP.MuteAudioOutput = MuteAudioOutput
	BSP.MuteAudioOutputs = MuteAudioOutputs
	BSP.SetConnectorVolume = SetConnectorVolume
	BSP.ChangeConnectorVolume = ChangeConnectorVolume
	BSP.SetZoneVolume = SetZoneVolume
	BSP.ChangeZoneVolume = ChangeZoneVolume
	BSP.SetZoneChannelVolume = SetZoneChannelVolume
	BSP.ChangeZoneChannelVolume = ChangeZoneChannelVolume

    BSP.SetVideoVolume = SetVideoVolume
	BSP.SetVideoVolumeByConnector = SetVideoVolumeByConnector
	BSP.ChangeVideoVolumeByConnector = ChangeVideoVolumeByConnector
	BSP.IncrementVideoVolumeByConnector = IncrementVideoVolumeByConnector
	BSP.DecrementVideoVolumeByConnector = DecrementVideoVolumeByConnector
    BSP.ChangeVideoVolume = ChangeVideoVolume
    BSP.IncrementVideoVolume = IncrementVideoVolume
    BSP.DecrementVideoVolume = DecrementVideoVolume
    BSP.SetVideoChannnelVolume = SetVideoChannnelVolume
    BSP.IncrementVideoChannnelVolumes = IncrementVideoChannnelVolumes
    BSP.DecrementVideoChannnelVolumes = DecrementVideoChannnelVolumes
    
    BSP.SetAudioVolume = SetAudioVolume
	BSP.SetAudioVolumeByConnector = SetAudioVolumeByConnector
	BSP.ChangeAudioVolumeByConnector = ChangeAudioVolumeByConnector
	BSP.IncrementAudioVolumeByConnector = IncrementAudioVolumeByConnector
	BSP.DecrementAudioVolumeByConnector = DecrementAudioVolumeByConnector
    BSP.ChangeAudioVolume = ChangeAudioVolume
    BSP.IncrementAudioVolume = IncrementAudioVolume
    BSP.DecrementAudioVolume = DecrementAudioVolume
    BSP.SetAudioChannnelVolume = SetAudioChannnelVolume
    BSP.IncrementAudioChannelVolumes = IncrementAudioChannelVolumes
    BSP.DecrementAudioChannelVolumes = DecrementAudioChannelVolumes
    
	BSP.SetAudioVolumeLimits = SetAudioVolumeLimits
    
	BSP.GetZone = GetZone
	BSP.GetVideoZone = GetVideoZone

    BSP.ChangeChannelVolumes = ChangeChannelVolumes
    BSP.SetChannelVolumes = SetChannelVolumes
    
    BSP.PauseVideo = PauseVideo
    BSP.ResumeVideo = ResumeVideo
    BSP.SetPowerSaveMode = SetPowerSaveMode
    
    BSP.CecDisplayOn = CecDisplayOn
    BSP.CecDisplayOff = CecDisplayOff
    BSP.CecPhilipsSetVolume = CecPhilipsSetVolume
    BSP.SendCecCommand = SendCecCommand
    
    BSP.WaitForSyncResponse = WaitForSyncResponse
    
    BSP.XMLAutoschedule = XMLAutoSchedule

    BSP.GetNonPrintableKeyboardCode = GetNonPrintableKeyboardCode
    BSP.InitializeNonPrintableKeyboardCodeList = InitializeNonPrintableKeyboardCodeList

	BSP.ConfigureBPs = ConfigureBPs
	BSP.ConfigureBP = ConfigureBP
	BSP.ConfigureBPButton = ConfigureBPButton
	BSP.ConfigureBPInput = ConfigureBPInput
	
    BSP.GetID = GetID
    BSP.GetCurrentStatus = GetCurrentStatus
	BSP.GetUDPEvents = GetUDPEvents
	BSP.GetRemoteData = GetRemoteData
    BSP.FilePosted = FilePosted
    BSP.SyncSpecPosted = SyncSpecPosted
    BSP.PrepareForTransfer = PrepareForTransfer
    BSP.FreeSpaceOnDrive = FreeSpaceOnDrive
	
	BSP.GetBoseProductSpec = GetBoseProductSpec
	
	BSP.CreateSerial = CreateSerial
	BSP.CreateUDPSender = CreateUDPSender

	BSP.rssFileIndex% = 0
	BSP.GetRSSTempFilename = GetRSSTempFilename
		
	BSP.ReadVariablesDB = ReadVariablesDB
	BSP.CreateDBTable = CreateDBTable
	BSP.AddDBSection = AddDBSection
	BSP.AddDBVariable = AddDBVariable
	BSP.UpdateDBVariable = UpdateDBVariable
	BSP.SetDBVersion = SetDBVersion
	BSP.GetDBSectionId = GetDBSectionId

	BSP.ExportVariablesDBToAsciiFile = ExportVariablesDBToAsciiFile
	BSP.GetUserVariable = GetUserVariable
	BSP.ResetVariables = ResetVariables
	BSP.ChangeUserVariableValue = ChangeUserVariableValue

	BSP.CheckBLCsStatus = CheckBLCsStatus
	BSP.CheckBLCStatus = CheckBLCStatus

	BSP.UpdateIPAddressUserVariables = UpdateIPAddressUserVariables
	BSP.UpdateRFChannelCountUserVariables = UpdateRFChannelCountUserVariables
	BSP.UpdateEdidUserVariables = UpdateEdidUserVariables

	BSP.GetAttachedFiles = GetAttachedFiles

    return BSP
    
End Function

'endregion

'region Local Web server
Sub GetConfigurationPage(userData as Object, e as Object)

    mVar = userData.mVar

'	print "respond to GetConfigurationPage request"
	e.AddResponseHeader("Content-type", "text/html; charset=utf-8")

	if type(mVar.sign) = "roAssociativeArray" and mVar.sign.deviceWebPageDisplay$ = "None" then

		e.SetResponseBodyString("")
		if not e.SendResponse(403) then stop

	else if mVar.deviceWebPageFilePath$ <> ""

		webPageContents$ = ReadAsciiFile(mVar.deviceWebPageFilePath$)
		e.SetResponseBodyString(webPageContents$)
		if not e.SendResponse(200) then stop

	else
	
		e.SetResponseBodyString("")
		if not e.SendResponse(404) then stop

	endif

End Sub


Sub SendUdpRest(userData as Object, e as Object)

  mVar = userData.mVar 
  args = e.GetFormData()
  CreateUDPSender(mVar)
  for each key in args
     value=args[key]
     mVar.udpSender.Send(value)
''     print "sendUDP key: "+key+" value: "+value
  next
  if not e.SendResponse(200) then stop

end Sub


Sub SetValues(userData as Object, e as Object)

'	print "respond to SetValues request"

    mVar = userData.mVar

    args = e.GetFormData()
'   print args

	userVariables = invalid
	if type(mVar.userVariableSets) = "roAssociativeArray" then
		for each presentationName in mVar.userVariableSets
			if presentationName = mVar.activePresentation$ then
				userVariables = mVar.userVariableSets.Lookup(presentationName)
				exit for
			endif
		next
	endif

	userVariablesUpdated = false

	if type(userVariables) = "roAssociativeArray" then
		for each userVariableName in args
			if userVariables.DoesExist(userVariableName) then
				userVariable = userVariables.Lookup(userVariableName)
				userVariable.SetCurrentValue(args.Lookup(userVariableName), false)
				userVariablesUpdated = true
			endif
		next
	endif

	e.AddResponseHeader("Location", e.GetRequestHeader("Referer"))
	if not e.SendResponse(302) then stop

	if userVariablesUpdated then
		userVariablesChanged = CreateObject("roAssociativeArray")
		userVariablesChanged["EventType"] = "USER_VARIABLES_UPDATED"
		mVar.msgPort.PostMessage(userVariablesChanged)
	endif

End Sub


Sub PopulateIDData(mVar As Object, root As Object)

    unitName$ = mVar.registrySettings.unitName$
    unitNamingMethod$ = mVar.registrySettings.unitNamingMethod$
    unitDescription$ = mVar.registrySettings.unitDescription$

    elem = root.AddElement("unitName")
    elem.SetBody(unitName$)

    elem = root.AddElement("unitNamingMethod")
    elem.SetBody(unitNamingMethod$)

    elem = root.AddElement("unitDescription")
    elem.SetBody(unitDescription$)

    elem = root.AddElement("serialNumber")
    elem.SetBody(mVar.sysInfo.deviceUniqueID$)

    elem = root.AddElement("functionality")
    elem.SetBody(mVar.lwsConfig$)
    
End Sub


Sub PopulateUDPData(mVar As Object, root As Object)

	sign = mVar.sign

	if type(sign) = "roAssociativeArray" then

		elem = root.AddElement("receivePort")
		elem.SetBody(StripLeadingSpaces(stri(sign.udpReceivePort)))

		elem = root.AddElement("destinationPort")
		elem.SetBody(StripLeadingSpaces(stri(sign.udpSendPort)))

		udpEvents = { }
		for each zoneHSM in sign.zonesHSM
			for each stateName in zoneHSM.stateTable

				state = zoneHSM.stateTable[stateName]

				udpEventsInState = state.udpEvents
				if type(udpEventsInState) = "roAssociativeArray" then
					for each udpEventName in udpEventsInState
						if not udpEvents.DoesExist(udpEventName) then
							udpEvents.AddReplace(udpEventName, udpEventName)
						endif
					next
				endif

				if state.type$ = "rfInputChannel" then
					if type(state.channelUpEvent) = "roAssociativeArray" and IsString(state.channelUpEvent.udpUserEvent$) then
						udpEvents.AddReplace(state.channelUpEvent.udpUserEvent$, state.channelUpEvent.udpUserEvent$)
					endif

					if type(state.channelDownEvent) = "roAssociativeArray" and IsString(state.channelDownEvent.udpUserEvent$) then
						udpEvents.AddReplace(state.channelDownEvent.udpUserEvent$, state.channelDownEvent.udpUserEvent$)
					endif
				endif

			next
		next

		udpEventsElem = root.AddElement("udpEvents")

		for each udpEvent in udpEvents
			udpEventElem = udpEventsElem.AddElement("udpEvent")
			udpEventLabel = udpEventElem.AddElement("label")
			udpEventLabel.SetBody(udpEvent)
			udpEventAction = udpEventElem.AddElement("action")
			udpEventAction.SetBody(udpEvent)
		next

	endif

End Sub


Sub GetID(userData as Object, e as Object)

    mVar = userData.mVar
    
'    print "respond to GetID request"

    root = CreateObject("roXMLElement")
    root.SetName("BrightSignID")

	PopulateIDData(mVar, root)

    xml = root.GenXML({ indent: " ", newline: chr(10), header: true })

    e.AddResponseHeader("Content-type", "text/xml")
    e.SetResponseBodyString(xml)
    e.SendResponse(200)
      
End Sub


Sub GetUDPEvents(userData as Object, e as Object)

  print "GetUDPEvents"
    mVar = userData.mVar

    root = CreateObject("roXMLElement")
    root.SetName("BrightSignUDPEvents")

	PopulateUDPData(mVar, root)

    xml = root.GenXML({ indent: " ", newline: chr(10), header: true })

    e.AddResponseHeader("Content-type", "text/xml")
    e.SetResponseBodyString(xml)
    e.SendResponse(200)

End Sub


Sub GetRemoteData(userData as Object, e as Object)

    mVar = userData.mVar
    
'    print "respond to GetRemoteData request"

    root = CreateObject("roXMLElement")
    root.SetName("BrightSignRemoteData")

	PopulateIDData(mVar, root)

	PopulateUDPData(mVar, root)

    elem = root.AddElement("contentPort")
    elem.SetBody("8008")

    xml = root.GenXML({ indent: " ", newline: chr(10), header: true })

    e.AddResponseHeader("Content-type", "text/xml")
    e.SetResponseBodyString(xml)
    e.SendResponse(200)

End Sub


Function GetSortedUserVariables(mVar As Object) As Object

	userVariablesList = []
	if type(mVar.userVariableSets) = "roAssociativeArray" then
		for each presentationName in mVar.userVariableSets
			if presentationName = mVar.activePresentation$ then
				userVariables = mVar.userVariableSets.Lookup(presentationName)
				for each variableName in userVariables
					userVariable = userVariables.Lookup(variableName)
					userVariablesList.push(userVariable)
				next
			endif
		next
	endif

	BubbleSortUserVariables(userVariablesList)

	return userVariablesList

End Function


Sub BubbleSortUserVariables(userVariables As Object)

	if type(userVariables) = "roArray" then
	
		n = userVariables.Count()

		while n <> 0

			newn = 0
			for i = 1 to (n - 1)
				if userVariables[i-1].name$ > userVariables[i].name$ then
					k = userVariables[i]
					userVariables[i] = userVariables[i-1]
					userVariables[i-1] = k
					newn = i
				endif
			next
			n = newn

		end while

	endif

End Sub


Sub PopulateUserVarData(mVar As Object, root As Object)

	sortedUserVariables = GetSortedUserVariables(mVar)
	for each userVariable in sortedUserVariables
		variableName = userVariable.name$
		elem = root.AddElement("BrightSignVar")
		elem.AddAttribute("name",variableName)
		elem.SetBody(userVariable.GetCurrentValue())
	next

End Sub


Sub GetUserVars(userData as Object, e as Object)

    mVar = userData.mVar

	e.AddResponseHeader("Content-type", "text/xml; charset=utf-8")

    root = CreateObject("roXMLElement")
    root.SetName("BrightSignUserVariables")

	PopulateUserVarData(mVar, root)

    xml = root.GenXML({ indent: " ", newline: chr(10), header: true })

    e.AddResponseHeader("Content-type", "text/xml")
    e.SetResponseBodyString(xml)
    e.SendResponse(200)
      
End Sub


Sub GetCurrentStatus(userData as Object, e as Object)
    
    mVar = userData.mVar
    
'    print "respond to GetCurrentStatus request"
  
    root = CreateObject("roXMLElement")
    root.SetName("BrightSignStatus")

    autorunVersion$ = mVar.sysInfo.autorunVersion$

    unitName$ = mVar.registrySettings.unitName$
    unitNamingMethod$ = mVar.registrySettings.unitNamingMethod$
    unitDescription$ = mVar.registrySettings.unitDescription$
    
    elem = root.AddElement("unitName")
    elem.AddAttribute("label", "Unit Name")
    elem.SetBody(unitName$)

    elem = root.AddElement("unitNamingMethod")
    elem.AddAttribute("label", "Unit Naming Method")
    elem.SetBody(unitNamingMethod$)

    elem = root.AddElement("unitDescription")
    elem.AddAttribute("label", "Unit Description")
    elem.SetBody(unitDescription$)

    modelObject = CreateObject("roDeviceInfo")
    
    elem = root.AddElement("model")
    elem.AddAttribute("label", "Model")
    elem.SetBody(modelObject.GetModel())

    elem = root.AddElement("firmware")
    elem.AddAttribute("label", "Firmware")
    elem.SetBody(modelObject.GetVersion())

    elem = root.AddElement("autorun")
    elem.AddAttribute("label", "Autorun")
    elem.SetBody(mVar.sysInfo.autorunVersion$)

    elem = root.AddElement("serialNumber")
    elem.AddAttribute("label", "Serial Number")
    elem.SetBody(modelObject.GetDeviceUniqueId())

    elem = root.AddElement("functionality")
    elem.AddAttribute("label", "Functionality")
    elem.SetBody(mVar.lwsConfig$)
    
' 86400 seconds per day
    deviceUptime% = modelObject.GetDeviceUptime()
    numDays% = deviceUptime% / 86400
    numHours% = (deviceUptime% - (numDays% * 86400)) / 3600
    numMinutes% = (deviceUptime% - (numDays% * 86400) - (numHours% * 3600)) / 60
    numSeconds% = deviceUptime% - (numDays% * 86400) - (numHours% * 3600) - (numMinutes% * 60)
    deviceUptime$ = ""
    if numDays% > 0 then deviceUptime$ = stri(numDays%) + " days "
    if numHours% > 0 then deviceUptime$ = deviceUptime$ + stri(numHours%) + " hours "
    if numMinutes% > 0 then deviceUptime$ = deviceUptime$ + stri(numMinutes%) + " minutes "
    if numSeconds% > 0 then deviceUptime$ = deviceUptime$ + stri(numSeconds%) + " seconds"
            
    elem = root.AddElement("deviceUptime")
    elem.AddAttribute("label", "Device Uptime")
    elem.SetBody(deviceUptime$)
    
    elem = root.AddElement("activePresentation")
    elem.AddAttribute("label", "Active Presentation")
    elem.SetBody(mVar.activePresentation$)
    
'    xml = root.GenXML({ indent: " ", newline: chr(10), header: true })
    xml = root.GenXML({ header: true })

    e.AddResponseHeader("Content-type", "text/xml")
    e.SetResponseBodyString(xml)
    e.SendResponse(200)
  
End Sub


Sub FilePosted(userData as Object, e as Object)

'    print "respond to FilePosted request"

	destinationFilename = e.GetRequestHeader("Destination-Filename")

	currentDir$ = "pool/"
	poolDepth% = 2
	while poolDepth% > 0
		newDir$ = Left(Right(destinationFilename, poolDepth%), 1)
		currentDir$ = currentDir$ + newDir$ + "/"
		CreateDirectory(currentDir$)
		poolDepth% = poolDepth% - 1
	end while

	regex = CreateObject("roRegEx","/","i")
	fileParts = regex.Split(destinationFilename)

	fullFilePath$ = currentDir$ + fileParts[1]

	MoveFile(e.GetRequestBodyFile(), fullFilePath$)

	e.SetResponseBodyString("RECEIVED")
    e.SendResponse(200)

End Sub


Function GetContentFiles(topDir$ As String) As Object

	allFiles = { }

	firstLevelDirs = MatchFiles(topDir$, "*")
	for each firstLevelDir in firstLevelDirs
		firstLevelDirSpec$ = topDir$ + firstLevelDir + "/"
		secondLevelDirs = MatchFiles(firstLevelDirSpec$, "*")
		for each secondLevelDir in secondLevelDirs
			secondLevelDirSpec$ = firstLevelDirSpec$ + secondLevelDir + "/"
			files = MatchFiles(secondLevelDirSpec$, "*")
			for each file in files
				allFiles.AddReplace(file, secondLevelDirSpec$)
			next
		next
	next

	return allFiles

End Function

'endregion

'region Sync
Function FreeSpaceOnDrive() As Object

    filesToPublish$ = ReadAsciiFile("filesToPublish.xml")
    if filesToPublish$ = "" then stop

' files that need to be copied by BrightAuthor
    filesToCopy = CreateObject("roAssociativeArray")
    
' files that can be deleted to make room for more content    
    deletionCandidates = CreateObject("roAssociativeArray")
    oldLocationDeletionCandidates = CreateObject("roAssociativeArray")

' create list of files already on the card
    listOfOldPoolFiles = MatchFiles("/pool", "*")
    for each file in listOfOldPoolFiles
        oldLocationDeletionCandidates.AddReplace(file, file)
    next

    listOfPoolFiles = GetContentFiles("/pool/")
    for each file in listOfPoolFiles
        deletionCandidates.AddReplace(file, listOfPoolFiles.Lookup(file))
    next
        
' create the list of files that need to be copied. this is the list of files in filesToPublish that are not in listOfPoolFiles
    filesToPublish = CreateObject("roXMLElement")
    filesToPublish.Parse(filesToPublish$)

' determine total space required
    totalSpaceRequired! = 0    
    for each fileXML in filesToPublish.file
        fullFileName$ = fileXML.fullFileName.GetText()
        o = deletionCandidates.Lookup(fullFileName$)
        if not IsString(o) then
        
            fileItem = CreateObject("roAssociativeArray")
            fileItem.fileName$ = fileXML.fileName.GetText()
            fileItem.filePath$ = fileXML.filePath.GetText()
            fileItem.hashValue$ = fileXML.hashValue.GetText()
            fileItem.fileSize$ = fileXML.fileSize.GetText()

            filesToCopy.AddReplace(fullFileName$, fileItem)

            fileSize% = val(fileItem.fileSize$)
            totalSpaceRequired! = totalSpaceRequired! + fileSize%
            
        endif
    next
    filesToPublish = invalid

' determine if additional space is required
	du = CreateObject("roStorageInfo", "./")
    freeInMegabytes! = du.GetFreeInMegabytes()
    totalFreeSpace! = freeInMegabytes! * 1048576
    
' print "totalFreeSpace = "; totalFreeSpace!;", totalSpaceRequired = ";totalSpaceRequired!
        
    if totalFreeSpace! < totalSpaceRequired! then
    
' parse local-sync.xml - remove its files from deletionCandidates
        localSync$ = ReadAsciiFile("local-sync.xml")
        if localSync$ <> "" then
            localSync = CreateObject("roXMLElement")
            localSync.Parse(localSync$)

            for each fileXML in localSync.files.download
                hashValue$ = fileXML.hash.GetText()
                hashMethod$ = fileXML.hash@method
                fileName$ = hashMethod$ + "-" + hashValue$
                fileExisted = deletionCandidates.Delete(fileName$)
				if not fileExisted then
	                fileExisted = oldLocationDeletionCandidates.Delete(fileName$)
				endif
	        next
        endif

' parse filesToPublish.xml - remove its files from deletionCandidates
        
        filesToPublish = CreateObject("roXMLElement")
        filesToPublish.Parse(filesToPublish$)
        
        for each fileXML in filesToPublish.file
            fullFileName$ = fileXML.fullFileName.GetText()
            fileExisted = deletionCandidates.Delete(fullFileName$)
        next

' delete all files that used the old style pool strategy that aren't currently in use
		for each fileToDelete in oldLocationDeletionCandidates
            pathOnCard$ = "/pool/" + fileToDelete
            oldLocationDeletionCandidates.Delete(fileToDelete)
            ok = DeleteFile(pathOnCard$)
		next

' delete files from deletionCandidates until totalFreeSpace! > totalSpaceRequired!

        for each fileToDelete in deletionCandidates
        
			path$ = deletionCandidates.Lookup(fileToDelete)
            pathOnCard$ = path$ + fileToDelete
            deletionCandidates.Delete(fileToDelete)
            DeleteFile(pathOnCard$)
            
            du = invalid
            du = CreateObject("roStorageInfo", "./")
            freeInMegabytes! = du.GetFreeInMegabytes()
            totalFreeSpace! = freeInMegabytes! * 1048576
            
' print "Delete file ";pathOnCard$        
' print "totalFreeSpace = "; totalFreeSpace!;", totalSpaceRequired = ";totalSpaceRequired!

            if totalFreeSpace! > totalSpaceRequired! then
                return filesToCopy
            endif

        next
        
        return "fail"
            
    endif
    
    return filesToCopy
    
End Function


Sub PrepareForTransfer(userData as Object, e as Object)

    mVar = userData.mVar
    
'    print "respond to PrepareForTransfer request"

    MoveFile(e.GetRequestBodyFile(), "filesToPublish.xml")
    
    filesToCopy = mVar.FreeSpaceOnDrive()
    if type(filesToCopy) = "roAssociativeArray" then

        root = CreateObject("roXMLElement")
        
        root.SetName("filesToCopy")

        for each key in filesToCopy
        
            fileItem = filesToCopy[key]
            
            item = root.AddBodyElement()
            item.SetName("file")

            elem = item.AddElement("fileName")
            elem.SetBody(fileItem.fileName$)
        
            elem = item.AddElement("filePath")
            elem.SetBody(fileItem.filePath$)
        
            elem = item.AddElement("hashValue")
            elem.SetBody(fileItem.hashValue$)
        
            elem = item.AddElement("fileSize")
            elem.SetBody(fileItem.fileSize$)
        
        next

        xml = root.GenXML({ header: true })

		e.SetResponseBodyString(xml)
		e.SendResponse(200)
            
    else
' the following call is ignored on a post
'		e.SetResponseBodyString("413")
		e.SendResponse(413)
    endif
        
End Sub


Sub SyncSpecPosted(userData as Object, e as Object)

    EVENT_REALIZE_SUCCESS = 101

    mVar = userData.mVar
    
'    print "respond to SyncSpecPosted request"

'    MoveFile(e.GetRequestBodyFile(), "tmp:new-sync.xml")
    MoveFile(e.GetRequestBodyFile(), "new-sync.xml")
    e.SetResponseBodyString("RECEIVED")
    e.SendResponse(200)
    
    oldSync = CreateObject("roSyncSpec")
    ok = oldSync.ReadFromFile("local-sync.xml")
    if not ok then stop
    
	newSync = CreateObject("roSyncSpec")
	ok = newSync.ReadFromFile("new-sync.xml")
    if not ok then stop

	oldSyncSpecScriptsOnly  = oldSync.FilterFiles("download", { group: "script" } )
	newSyncSpecScriptsOnly  = newSync.FilterFiles("download", { group: "script" } )

'	listOfDownloadFiles = newSyncSpecScriptsOnly.GetFileList("download")
'    for each downloadFile in listOfDownloadFiles
'		print "name = ";downloadFile.name
'		print "size = ";downloadFile.size
'		print "hash = ";downloadFile.hash
'	next

    mVar.diagnostics.PrintTimestamp()
    mVar.diagnostics.PrintDebug("### LWS DOWNLOAD COMPLETE")
            
    mVar.syncPoolFiles = CreateObject("roSyncPoolFiles", "pool", newSync)
    if type(mVar.syncPoolFiles) <> "roSyncPoolFiles" then stop

'	tmpSyncPool = CreateObject("roSyncPool", "pool")
'	if type(tmpSyncPool) = "roSyncPool" then
'        filesInPoolStatus = tmpSyncPool.QueryFiles(newSync)
'		for each fileInPoolStatus in filesInPoolStatus
'			print fileInPoolStatus;" ";filesInPoolStatus.Lookup(fileInPoolStatus)
'		next
'    endif

	rebootRequired = false

	if not oldSyncSpecScriptsOnly.FilesEqualTo(newSyncSpecScriptsOnly) then

		tmpSyncPool = CreateObject("roSyncPool", "pool")

		' Protect all the media files that the current sync spec is using in case we fail part way 
		' through and need to continue using it. 
		if not (tmpSyncPool.ProtectFiles(oldSync, 0) and tmpSyncPool.ProtectFiles(newSync, 0)) then
			print "Failed to protect files that we need in the pool"
			stop	
		endif   

		event = tmpSyncPool.Realize(newSyncSpecScriptsOnly, "/")
		if event.GetEvent() <> EVENT_REALIZE_SUCCESS then
	        mVar.logging.WriteDiagnosticLogEntry(mVar.diagnosticCodes.EVENT_REALIZE_FAILURE, stri(event.GetEvent()) + chr(9) + event.GetName() + chr(9) + event.GetFailureReason())
			mVar.diagnostics.PrintDebug("### Realize failed " + stri(event.GetEvent()) + chr(9) + event.GetName() + chr(9) + event.GetFailureReason() )
			tmpSyncPool = invalid
			DeleteFile("new-sync.xml")
			newSync = invalid
			return
		else
			rebootRequired = true
		endif
	
	endif

	if not newSync.WriteToFile("local-sync.xml") then stop

	' cause fsync
	CreateObject("roReadFile", "local-sync.xml")

    if rebootRequired then
        mVar.diagnostics.PrintDebug("### new script or upgrade found - reboot")
        RebootSystem()
    endif

	globalAA = GetGlobalAA()
    globalAA.autoscheduleFilePath$ = GetPoolFilePath(mVar.syncPoolFiles, "autoschedule.xml")
    globalAA.resourcesFilePath$ = GetPoolFilePath(mVar.syncPoolFiles, "resources.txt")
    globalAA.boseProductsFilePath$ = GetPoolFilePath(mVar.syncPoolFiles, "BoseProducts.xml")
    if globalAA.autoscheduleFilePath$ = "" then stop
                
	DeleteFile("new-sync.xml")
	newSync = invalid

' send internal message to prepare for restart
    prepareForRestartEvent = CreateObject("roAssociativeArray")
    prepareForRestartEvent["EventType"] = "PREPARE_FOR_RESTART"
    mVar.msgPort.PostMessage(prepareForRestartEvent)

' send internal message indicating that new content is available
    contentUpdatedEvent = CreateObject("roAssociativeArray")
    contentUpdatedEvent["EventType"] = "CONTENT_UPDATED"
    mVar.msgPort.PostMessage(contentUpdatedEvent)
    
End Sub

'endregion

'region Presentation
Sub ConfigureBPInput(buttonPanelIndex% As Integer, buttonNumber$ As String)

	if buttonNumber$ = "-1" then
		for i% = 0 to 10
			m.bpStateMachineRequired[buttonPanelIndex%, i%] = true
		next
	else
	    buttonNumber% = int(val(buttonNumber$))
	    m.bpStateMachineRequired[buttonPanelIndex%, buttonNumber%] = true
	    m.bpInputUsed[buttonPanelIndex%, buttonNumber%] = true
	endif

End Sub


Sub ConfigureBPButton(buttonPanelIndex% As Integer, buttonNumber$ As String, bpSpec As Object)

	if buttonNumber$ = "-1" then
	    for i% = 0 to 10
			if type(m.bpSM[buttonPanelIndex%, i%]) = "roAssociativeArray" then
				m.bpSM[buttonPanelIndex%, i%].ConfigureButton(bpSpec)
			endif
		next
	else
		buttonNumber% = int(val(buttonNumber$))
		if type(m.bpSM[buttonPanelIndex%, buttonNumber%]) = "roAssociativeArray" then
			m.bpSM[buttonPanelIndex%, buttonNumber%].ConfigureButton(bpSpec)
		endif
	endif
	
End Sub


Function NewGlobalVariables() As Object

    globalVariables = CreateObject("roAssociativeArray")
    globalVariables.language$ = "eng"
    
    return globalVariables
    
End Function


Function newPresentation(bsp As Object, presentationXML As Object) As Object

	presentation = {}
	presentation.name$ = presentationXML.name.GetText()
	presentation.presentationName$ = presentationXML.presentationName.GetText()
	presentation.path$ = presentationXML.path.GetText()

	' for earlier 3.7 presentations
	if presentation.presentationName$ = "" then
		presentation.presentationName$ = presentation.path$
	endif

	return presentation

End Function


Function newScriptPlugin(scriptPluginXML As Object) As Object

	scriptPlugin = {}
	scriptPlugin.name$ = scriptPluginXML.name.GetText()
	scriptPlugin.plugin = invalid

	return scriptPlugin

End Function


Function newHTMLSite(bsp As Object, htmlSiteXML As Object) As Object

	htmlSite = {}

	htmlSite.name$ = htmlSiteXML.name.GetText()

	if htmlSiteXML.GetName() = "localHTMLSite" then
		htmlSite.prefix$ = htmlSiteXML.prefix.GetText()
		htmlSite.filePath$ = htmlSiteXML.filePath.GetText()
		htmlSite.contentIsLocal = true
	else if htmlSiteXML.GetName() = "remoteHTMLSite" then
		htmlSite.url = newParameterValue(bsp, htmlSiteXML.url.parameterValue)
		htmlSite.contentIsLocal = false
	endif

	return htmlSite

End Function


Function newLiveDataFeed(bsp As Object, liveDataFeedXML As Object) As Object

	liveDataFeed = {}
	liveDataFeed.name$ = liveDataFeedXML.name.GetText()

	liveBSNDataFeedXMLList = liveDataFeedXML.GetNamedElements("liveBSNDataFeed")
	liveDynamicPlaylistXMLList = liveDataFeedXML.GetNamedElements("liveDynamicPlaylist")

	if liveBSNDataFeedXMLList.Count() = 1 then
		urlSpec$ = liveDataFeedXML.liveBSNDataFeed.url.GetText()
		liveDataFeed.url = newTextParameterValue(urlSpec$)
	else if liveDynamicPlaylistXMLList.Count() = 1 then
		urlSpec$ = liveDataFeedXML.liveDynamicPlaylist.url.GetText()
		liveDataFeed.url = newTextParameterValue(urlSpec$)
	else
		liveDataFeed.url = newParameterValue(bsp, liveDataFeedXML.url.parameterValue)
	endif

	liveDataFeed.parser$ = liveDataFeedXML.parserFunctionName.GetText()
	liveDataFeed.updateInterval% = int(val(liveDataFeedXML.updateInterval.GetText()))

	return liveDataFeed

End Function


Function newLiveDataFeedFromOldDataFormat(url As Object, updateInterval% As Integer) As Object

	liveDataFeed = {}
	liveDataFeed.name$ = url.GetCurrentParameterValue()
	liveDataFeed.url = url
	liveDataFeed.parser$ = ""
	liveDataFeed.updateInterval% = updateInterval%

	return liveDataFeed

End Function


Function newLiveDataFeedWithAuthDataFromOldDataFormat(url As Object, authData As Object, updateInterval% As Integer) As Object

	liveDataFeed = {}
	liveDataFeed.name$ = url.GetCurrentParameterValue()
	liveDataFeed.url = url
	liveDataFeed.authenticationData = authData
	liveDataFeed.parser$ = ""
	liveDataFeed.updateInterval% = updateInterval%

	return liveDataFeed

End Function


Sub Restart(presentationName$ As String)

	m.liveDataFeeds = { }
	m.presentations = { }
	m.htmlSites = { }
	m.scriptPlugins = CreateObject("roArray", 1, true)
	m.additionalPublishedFiles = CreateObject("roArray", 1, true)

	for n% = 0 to 2
		for i% = 0 to 10
			m.bpStateMachineRequired[n%, i%] = false
			m.bpInputUsed[n%, i%] = false
			m.bpOutputUsed[n%, i%] = false
		next
	next

	if presentationName$ = "" then

		globalAA = GetGlobalAA()
		xmlAutoscheduleFile$ = ReadAsciiFile(globalAA.autoscheduleFilePath$)
		if xmlAutoscheduleFile$ <> "" then
			schedule = m.XMLAutoschedule(globalAA.autoscheduleFilePath$)
		else
			stop
		endif
         
		if type(schedule.activeScheduledEvent) = "roAssociativeArray" then
			xmlFileName$ = schedule.autoplayPoolFile$
		else
			xmlFileName$ = ""
		endif
        
		m.schedule = schedule
	
	    if (xmlFileName$ <> "") then
			presentationName$ = schedule.activeScheduledEvent.presentationName$
		endif

	else

		autoplayFileName$ = "autoplay-" + presentationName$ + ".xml"
		xmlFileName$ = m.syncPoolFiles.GetPoolFilePath(autoplayFileName$)
        m.activePresentation$ = presentationName$

	endif

    if (xmlFileName$ <> "") then
        BrightAuthor = CreateObject("roXMLElement")
        BrightAuthor.Parse(ReadAsciiFile(xmlFileName$))
        
        ' verify that this is a valid BrightAuthor XML file
        if BrightAuthor.GetName() <> "BrightAuthor" then print "Invalid XML file - name not BrightAuthor" : stop
        if not IsString(BrightAuthor@version) then print "Invalid XML file - version not found" : stop    

        m.diagnostics.PrintTimestamp()
        m.diagnostics.PrintDebug("### create sign object")

        version% = int(val(BrightAuthor@version))
        
	    sign = newSign(BrightAuthor, m.globalVariables, m, m.msgPort, m.controlPort, version%)

		m.LogActivePresentation()

    else
        sign = invalid
    endif
    
    if type(m.sign) = "roAssociativeArray" and type(m.sign.zonesHSM) = "roArray" then
		for each zoneHSM in m.sign.zonesHSM
			if IsAudioPlayer(zoneHSM.audioPlayer) then
				zoneHSM.audioPlayer.Stop()
				zoneHSM.audioPlayer = invalid
			endif
			if type(zoneHSM.videoPlayer) = "roVideoPlayer" then
				zoneHSM.videoPlayer.Stop()
				zoneHSM.videoPlayer = invalid
			endif
		next
    endif

	zoneHSM = invalid
	m.dispatchingZone=invalid
	m.sign = invalid
	RunGarbageCollector()
    
    m.ClearImageBuffers()
    
    m.sign = sign	
	
	' create, initialize, and configure required BP state machines and BP's
	for buttonPanelIndex% = 0 to 2
		if type(m.bpInputPorts[buttonPanelIndex%]) = "roControlPort" then
			configuration% = m.bpInputPortConfigurations[buttonPanelIndex%]
		else
			configuration% = 0
		endif
		for i% = 0 to 10
			if (configuration% and (2 ^ i%)) <> 0 then
				forceUsed = true
			else
				forceUsed = false
			endif
'			if m.bpStateMachineRequired[buttonPanelIndex%, i%] then
			if (m.bpInputUsed[buttonPanelIndex%, i%] or forceUsed) and IsString(m.bpInputPortIdentities[buttonPanelIndex%]) and type(m.bpInputPorts[buttonPanelIndex%]) = "roControlPort" then
				m.bpSM[buttonPanelIndex%, i%] = newBPStateMachine(m, m.bpInputPortIdentities[buttonPanelIndex%], buttonPanelIndex%, i%)
			else
				m.bpSM[buttonPanelIndex%, i%] = invalid
			endif			
		next
    next

	m.ConfigureBPs()

	for buttonPanelIndex% = 0 to 2
	
		if type(m.bpOutputSetup[buttonPanelIndex%]) = "roControlPort" then
	
			configuration% = m.bpInputPortConfigurations[buttonPanelIndex%]

			' set bits in our mask for buttons we want to disable (not enable!)
			loopFlag% = 1
			buttonFlag% = 0

			for i% = 0 to 10
				if (configuration% and (2 ^ i%)) <> 0 then
					forceUsed = true
				else
					forceUsed = false
				endif
	'			if not (m.bpInputUsed[buttonPanelIndex%, i%] or m.bpOutputUsed[buttonPanelIndex%, i%]) then
	'			if not m.bpStateMachineRequired[buttonPanelIndex%, i%] then
				if not (m.bpInputUsed[buttonPanelIndex%, i%] or forceUsed) then
					buttonFlag% = buttonFlag% + loopFlag%
				endif

				loopFlag% = loopFlag% * 2
			next

			' the 1 here is the position of the mask for disabling buttons
			m.bpOutputSetup[buttonPanelIndex%].SetOutputValue(1, buttonFlag%)
		
			loopFlag% = 1
			ledFlag% = 0

			for i% = 0 to 10
				if (configuration% and (2 ^ i%)) <> 0 then
					forceUsed = true
				else
					forceUsed = false
				endif
			    if not (m.bpInputUsed[buttonPanelIndex%, i%] or m.bpOutputUsed[buttonPanelIndex%, i%] or forceUsed) then
				   ledFlag% = ledFlag% + loopFlag%
			    endif

			    loopFlag% = loopFlag% * 2
			next

			' the 2 here signifies the mask position for LED disabling
			m.bpOutputSetup[buttonPanelIndex%].SetOutputValue(2, ledFlag%)	
	
		endif
	
	next

	' reset connector volumes
	m.analogVolume% = 100
	m.analog2Volume% = 100
	m.analog3Volume% = 100
	m.hdmiVolume% = 100
	m.spdifVolume% = 100
	m.usbVolume% = 100

	' reclaim memory
	RunGarbageCollector()
	
	' if there are script plugins associated with this sign, initialize them here
	userVariables = invalid
	if type(m.userVariableSets) = "roAssociativeArray" then
		userVariables = m.userVariableSets.Lookup(m.activePresentation$)
	endif

	ERR_NORMAL_END = &hFC

	for each scriptPlugin in m.scriptPlugins
		initializeFunction$ = "result = " + scriptPlugin.name$ + "_Initialize(m.msgPort, userVariables, m)"
		retVal = Eval(initializeFunction$)
		if retVal <> ERR_NORMAL_END then
			' log the failure
		    m.diagnostics.PrintDebug("Failure executing Eval to initialize script plugin file: return value = " + stri(retVal) + ", call was " + initializeFunction$)
			m.logging.WriteDiagnosticLogEntry(m.diagnosticCodes.EVENT_SCRIPT_PLUGIN_FAILURE, stri(retVal) + chr(9) + scriptPlugin.name$)
		else
			scriptPlugin.plugin = result
		endif
	next

	' user variable web server
    if type(m.sign) = "roAssociativeArray" and m.registrySettings.lwsConfig$ = "c" or m.registrySettings.lwsConfig$ = "s" then

		lwsUserName$ = m.registrySettings.lwsUserName$
		lwsPassword$ = m.registrySettings.lwsPassword$
        
        if (len(lwsUserName$) + len(lwsPassword$)) > 0 then
            credentials = CreateObject("roAssociativeArray")
            credentials.AddReplace(lwsUserName$, lwsPassword$)
        else
            credentials = invalid
        end if
                        
        m.sign.localServer = CreateObject("roHttpServer", { port: 8008 })
        m.sign.localServer.SetPort(m.msgPort)

		m.sign.GetUserVarsAA =         { HandleEvent: GetUserVars, mVar: m }
    m.sign.GetConfigurationPageAA ={ HandleEvent: GetConfigurationPage, mVar: m }

		m.sign.SetValuesAA =			{ HandleEvent: SetValues, mVar: m }

		m.sign.localServer.AddGetFromFile({ url_path: "/GetAutorun", content_type: "text/plain; charset=utf-8", filename: "autorun.brs"})

		m.sign.localServer.AddGetFromEvent({ url_path: "/GetUserVars", user_data: m.sign.GetUserVarsAA})
		m.sign.localServer.AddGetFromEvent({ url_path: "/", user_data: m.sign.GetConfigurationPageAA, passwords: credentials})
    m.sign.localServer.AddPostToFormData({ url_path: "/SetValues", user_data: m.sign.SetValuesAA, passwords: credentials})

    ' adding GetUDPEvents'
    m.sign.GetUDPEventsAA = { HandleEvent: GetUDPEvents, mVar: m}
    m.sign.localServer.AddGetFromEvent({ url_path: "/GetUDPEvents", user_data: m.sign.GetUDPEventsAA })
    m.sign.SendUdpRestAA =     { HandleEvent: SendUdpRest, mVar: m }
    m.sign.localServer.AddPostToFormData({ url_path: "/SendUDP", user_data: m.sign.SendUdpRestAA })

    endif

	' device web page
	m.deviceWebPageFilePath$ = ""

	if type(m.sign) = "roAssociativeArray" and m.sign.deviceWebPageDisplay$ <> "None" then

		' get all the files in the device web page
        
		' FIX ME SOMEDAY - need a single object that represents the current sync spec
		currentSync = CreateObject("roSyncSpec")
		if not currentSync.ReadFromFile("current-sync.xml") then
			if not currentSync.ReadFromFile("local-sync.xml") then
				stop
			endif
		endif
		
		if m.sign.deviceWebPageDisplay$ = "Custom" then
		
			' files in the custom device web page start with
			' <presentation name>-<customDeviceWebPage>-
			customDeviceWebPagePrefix$ = m.activePresentation$ + "-" + "customDeviceWebPage-"
			prefixLength% = len(customDeviceWebPagePrefix$)

			downloadFiles = currentSync.GetFileList("download")
			for each downloadFile in downloadFiles
				fileName$ = downloadFile.name

				index% = instr(1, fileName$, customDeviceWebPagePrefix$)
				if index% = 1 then
					strippedFileName$ = mid(fileName$, prefixLength% + 1)

					' the main web page is
					' <presentation name>-<customDeviceWebPage>-<custom device web page>
					if strippedFileName$ = m.sign.customDeviceWebPage$ then

						m.deviceWebPageFilePath$ = GetPoolFilePath(m.syncPoolFiles, fileName$)

					else

						' other asset
						ext = GetFileExtension(strippedFileName$)
						if ext <> invalid then
							contentType$ = GetMimeTypeByExtension(ext)
							if contentType$ <> invalid then
								url$ = "/" + strippedFileName$
								filePath$ = GetPoolFilePath(m.syncPoolFiles, fileName$)
								m.sign.localServer.AddGetFromFile({ url_path: url$, filename: filePath$, content_type: contentType$ })
							endif
						endif

					endif
				endif

			next

		else

			m.deviceWebPageFilePath$ = GetPoolFilePath(m.syncPoolFiles, "_deviceWebPage.html")

		endif

	endif

End Sub


Function GetFileExtension(file as String) as Object
  s=file.tokenize(".")
  if s.Count()>1
    ext=s.pop()
    return ext
  end if
  return invalid
end Function

Function GetMimeTypeByExtension(ext as String) as String

  ' start with audio types '
  if ext="mp3"
    return "audio/mpeg"

  ' now image types '
  else if ext="gif"
    return "image/gif"
  else if ext="jpeg"
    return "image/jpeg"
  else if ext="jpg"
    return "image/jpeg"
  else if ext="png"
    return "image/png"
  else if ext="svg"
    return "image/svg+xml"

  ' now text types'
  else if ext="css"
    return "text/css"
  else if ext="js"
    return "application/JavaScript"
  else if ext="csv"
    return "text/csv"
  else if ext="html"
    return "text/html"
  else if ext="htm"
    return "text/html"
  else if ext="txt"
    return "text/plain"
  else if ext="xml"
    return "text/xml"

  ' now some video types'
  else if ext="mpeg"
    return "video/mpeg"
  else if ext="mp4"
    return "video/mp4"
  else if ext="ts"
    return "video/mpeg"
  end if
  return ""
end Function


Sub LogActivePresentation()

	if type(m.activePresentation$) = "roString" then
		activePresentation$ = m.activePresentation$
	else
		activePresentation$ = ""
	endif

	m.logging.WriteDiagnosticLogEntry(m.diagnosticCodes.EVENT_START_PRESENTATION, activePresentation$)

End Sub


Sub UpdateEdidUserVariables(postMsg As Boolean)

	if type(m.userVariableSets) = "roAssociativeArray" then
		if m.userVariableSets.DoesExist(m.activePresentation$) then
			userVariables = m.userVariableSets.Lookup(m.activePresentation$)
			for each userVariableKey in userVariables
				userVariable = userVariables.Lookup(userVariableKey)
				if userVariable.systemVariable$ = "edidMonitorSerialNumber" then
					userVariable.SetCurrentValue(m.bsp.sysInfo.edidMonitorSerialNumber$, postMsg)
				else if userVariable.systemVariable$ = "edidYearOfManufacture" then
					userVariable.SetCurrentValue(m.bsp.sysInfo.edidYearOfManufacture$, postMsg)
				else if userVariable.systemVariable$ = "edidMonitorName" then
					userVariable.SetCurrentValue(m.bsp.sysInfo.edidMonitorName$, postMsg)
				else if userVariable.systemVariable$ = "edidManufacturer" then
					userVariable.SetCurrentValue(m.bsp.sysInfo.edidManufacturer$, postMsg)
				else if userVariable.systemVariable$ = "edidUnspecifiedText" then
					userVariable.SetCurrentValue(m.bsp.sysInfo.edidUnspecifiedText$, postMsg)
				else if userVariable.systemVariable$ = "edidSerialNumber" then
					userVariable.SetCurrentValue(m.bsp.sysInfo.edidSerialNumber$, postMsg)
				else if userVariable.systemVariable$ = "edidManufacturerProductCode" then
					userVariable.SetCurrentValue(m.bsp.sysInfo.edidManufacturerProductCode$, postMsg)
				else if userVariable.systemVariable$ = "edidWeekOfManufacture" then
					userVariable.SetCurrentValue(m.bsp.sysInfo.edidWeekOfManufacture$, postMsg)
				endif
			next
		endif
	endif

End Sub


Sub UpdateIPAddressUserVariables(postMsg As Boolean)

	if type(m.userVariableSets) = "roAssociativeArray" then
		if m.userVariableSets.DoesExist(m.activePresentation$) then
			userVariables = m.userVariableSets.Lookup(m.activePresentation$)
			for each userVariableKey in userVariables
				userVariable = userVariables.Lookup(userVariableKey)
				if userVariable.systemVariable$ = "ipAddressWired" then
					userVariable.SetCurrentValue(m.sysInfo.ipAddressWired$, postMsg)
				else if userVariable.systemVariable$ = "ipAddressWireless" then
					userVariable.SetCurrentValue(m.sysInfo.ipAddressWireless$, postMsg)
				endif
			next
		endif
	endif

End Sub


Sub UpdateRFChannelCountUserVariables(postMsg As Boolean)

	if type(m.userVariableSets) = "roAssociativeArray" then
		if m.userVariableSets.DoesExist(m.activePresentation$) then
			userVariables = m.userVariableSets.Lookup(m.activePresentation$)
			for each userVariableKey in userVariables
				userVariable = userVariables.Lookup(userVariableKey)
				if userVariable.systemVariable$ = "rfChannelCount" then
					userVariable.SetCurrentValue(StripLeadingSpaces(stri(m.scannedChannels.Count())), postMsg)
				endif
			next
		endif
	endif

End Sub


Function GetScannedChannels() As Object

	channelDescriptors = CreateObject("roArray", 1, true)

	channelManager = CreateObject("roChannelManager")
	if type(channelManager) = "roChannelManager" then

		' Get channel descriptors for all the channels on the device
		channelCount% = channelManager.GetChannelCount()

		if channelCount% > 0 then

			channelInfo  = CreateObject("roAssociativeArray")

			for channelIndex% = 0 to channelCount% - 1
				channelInfo["ChannelIndex"] = channelIndex%
				channelDescriptor = channelManager.CreateChannelDescriptor(channelInfo)
				channelDescriptors.push(channelDescriptor)
			next
		endif
		
	endif

	return channelDescriptors

End Function

'endregion

'region Bose Products
Function ReadBoseProductsFile() As Object

    boseProductsFileXML = CreateObject("roXMLElement")
	globalAA = GetGlobalAA()
    boseProductsFileContents$ = ReadAsciiFile(globalAA.boseProductsFilePath$)
    if len(boseProductsFileContents$) = 0 then return 0
    
    boseProductsFileXML.Parse(boseProductsFileContents$)

    ' verify that this is a valid BoseProducts XML file
    if boseProductsFileXML.GetName() <> "BoseProducts" then print "Invalid BoseProducts XML file - name not BoseProducts" : stop
    if not IsString(boseProductsFileXML@version) then print "Invalid BoseProducts XML file - version not found" : stop    

    boseProductsXML = boseProductsFileXML.product
    numBoseProducts% = boseProductsXML.Count()

	boseProducts = CreateObject("roAssociativeArray")

    for each boseProductXML in boseProductsXML
		AddBoseProduct(boseProducts, boseProductXML)
    next

	return boseProducts
	
End Function


Sub AddBoseProduct(boseProducts As Object, boseProductXML As Object)

	boseProduct = CreateObject("roAssociativeArray")

	productName$ = boseProductXML.productName.GetText()

	volumeTable = CreateObject("roAssociativeArray")

	volumeTableElements = boseProductXML.GetNamedElements("volumeTable")
    if volumeTableElements.Count() <> 1 then stop
    
	volumeTableElement = volumeTableElements[0]
	
	xval1Elements = volumeTableElement.GetNamedElements("xval1")
	volumeTable.xval1% = int(val(xval1Elements[0].GetText()))
	
	yval1Elements = volumeTableElement.GetNamedElements("yval1")
	volumeTable.yval1% = int(val(yval1Elements[0].GetText()))
	
	xval2Elements = volumeTableElement.GetNamedElements("xval2")
	volumeTable.xval2% = int(val(xval2Elements[0].GetText()))
	
	yval2Elements = volumeTableElement.GetNamedElements("yval2")
	volumeTable.yval2% = int(val(yval2Elements[0].GetText()))
	
	xval3Elements = volumeTableElement.GetNamedElements("xval3")
	volumeTable.xval3% = int(val(xval3Elements[0].GetText()))
	
	yval3Elements = volumeTableElement.GetNamedElements("yval3")
	volumeTable.yval3% = int(val(yval3Elements[0].GetText()))
		
	boseProduct.volumeTable = volumeTable

	transportElements = boseProductXML.GetNamedElements("transport")
	if transportElements.Count() <> 1 then stop
	
	transportElement = transportElements[0]
	transportAttributes = transportElement.GetAttributes()
	transportType$ = transportAttributes.Lookup("type")
	boseProduct.protocol$ = "ASCII"
	if transportType$ = "Serial-Binary" then
		boseProduct.protocol$ = "Binary"
	endif
	
	baudRateElements = transportElement.GetNamedElements("baudRate")
	boseProduct.baudRate% = int(val(baudRateElements[0].GetText()))
	
	dataBitsElements = transportElement.GetNamedElements("dataBits")
	boseProduct.dataBits$ = dataBitsElements[0].GetText()
	
	parityElements = transportElement.GetNamedElements("parity")
	boseProduct.parity$ = parityElements[0].GetText()
	
	stopBitsElements = transportElement.GetNamedElements("stopBits")
	boseProduct.stopBits$ = stopBitsElements[0].GetText()
	
	invertSignalsElements = transportElement.GetNamedElements("invertSignals")
	invertSignals$ = invertSignalsElements[0].GetText()

	if invertSignals$ = "true" then
		boseProduct.invertSignals = true
	else
		boseProduct.invertSignals = false
	endif
	
	sendEol$ = "CR"
	sendEolElements = transportElement.GetNamedElements("sendEOL")
	if sendEolElements.Count() = 1 then
		if sendEolElements[0].GetText() <> "" then
			sendEol$ = sendEolElements[0].GetText()
		endif
	endif
	boseProduct.sendEol$ = sendEol$

	receiveEol$ = "CR"
	receiveEolElements = transportElement.GetNamedElements("receiveEOL")
	if receiveEolElements.Count() = 1 then
		if receiveEolElements[0].GetText() <> "" then
			receiveEol$ = receiveEolElements[0].GetText()
		endif
	endif
	boseProduct.receiveEol$ = receiveEol$
						
	boseProducts.AddReplace(productName$, boseProduct)
		
End Sub


Function GetBoseProductSpec(productName$) As Object

	if type(m.boseProductSpecs) = "roAssociativeArray" then
		return m.boseProductSpecs.Lookup(productName$)
	else
		return 0
	endif
	
End Function

'endregion

'region Schedule
Function XMLAutoschedule(xmlFileName$ As String)

    autoScheduleXML = CreateObject("roXMLElement")
    autoScheduleXML.Parse(ReadAsciiFile(xmlFileName$))
    
    ' verify that this is a valid autoschedule XML file
    if autoScheduleXML.GetName() <> "autoschedule" then print "Invalid autoschedule XML file - name not autoschedule" : stop
    if not IsString(autoScheduleXML@version) then print "Invalid autoschedule XML file - version not found" : stop    
'    print "autoschedule xml file - version = "; autoScheduleXML@version

    schedule = newSchedule(autoScheduleXML)

    if type(schedule.activeScheduledEvent) = "roAssociativeArray" then

        presentation$ = schedule.activeScheduledEvent.presentationName$
        m.activePresentation$ = presentation$
        
        autoplayFileName$ = "autoplay-" + presentation$ + ".xml"

		' find the autoplay file in the pool folder
	    currentSync = CreateObject("roSyncSpec")
	    if type(currentSync) = "roSyncSpec" then
	    
			ok = currentSync.ReadFromFile("current-sync.xml")
			if not ok then
				ok = currentSync.ReadFromFile("local-sync.xml")
				if not ok then stop
			endif
			
            spf = CreateObject("roSyncPoolFiles", "pool", currentSync)
            autoplayPoolFile$ = spf.GetPoolFilePath(autoplayFileName$)
            if autoplayPoolFile$ = "" then stop
			schedule.autoplayPoolFile$ = autoplayPoolFile$
            spf = invalid
            
        endif
		
        currentSync = invalid
    
    endif
    
    return schedule
    
End Function


Function newSchedule(autoScheduleXML As Object) As Object

    schedule = CreateObject("roAssociativeArray")

    ' create and read schedules
    scheduledPresentationsXML = autoScheduleXML.scheduledPresentation
    numScheduledPresentations% = scheduledPresentationsXML.Count()
    
    schedule.scheduledEvents = CreateObject("roArray", numScheduledPresentations%, true)
    
    for each scheduledPresentationXML in scheduledPresentationsXML
    
        scheduledPresentationBS = newScheduledEvent(scheduledPresentationXML)
        schedule.scheduledEvents.push(scheduledPresentationBS)
        
    next

    ' get starting presentation
    schedule.GetActiveScheduledEvent = GetActiveScheduledEvent    
    schedule.GetNextScheduledEventTime = GetNextScheduledEventTime
        
    schedule.activeScheduledEvent = schedule.GetActiveScheduledEvent()

    if type(schedule.activeScheduledEvent)<> "roAssociativeArray" then
        schedule.nextScheduledEventTime = schedule.GetNextScheduledEventTime()
    endif

    return schedule
    
End Function


Function newScheduledEvent(scheduledEventXML As Object) As Object

    scheduledEventBS = CreateObject("roAssociativeArray")
        
    if scheduledEventXML.playlist.Count() > 0 then
        scheduledEventBS.playlist$ = scheduledEventXML.playlist.GetText()
    endif
    if scheduledEventXML.presentationToSchedule.Count() > 0 then
        scheduledEventBS.presentationName$ = scheduledEventXML.presentationToSchedule.name.GetText()
    endif
    
    dateTime$ = scheduledEventXML.dateTime.GetText()    
    scheduledEventBS.dateTime = FixDateTime(dateTime$)
    
    scheduledEventBS.duration% = int(val(scheduledEventXML.duration.GetText()))
    
    if lcase(scheduledEventXML.allDayEveryDay.GetText()) = "true" then
        scheduledEventBS.allDayEveryDay = true
    else
        scheduledEventBS.allDayEveryDay = false
    endif
        
    if lcase(scheduledEventXML.recurrence.GetText()) = "true" then
        scheduledEventBS.recurrence = true
    else
        scheduledEventBS.recurrence = false
    endif
        
    scheduledEventBS.recurrencePattern$ = scheduledEventXML.recurrencePattern.GetText()
    
    scheduledEventBS.recurrencePatternDaily$ = scheduledEventXML.recurrencePatternDaily.GetText()

    scheduledEventBS.recurrencePatternDaysOfWeek% = int(val(scheduledEventXML.recurrencePatternDaysOfWeek.GetText()))
    
    dateTime$ = scheduledEventXML.recurrenceStartDate.GetText()    
    scheduledEventBS.recurrenceStartDate = FixDateTime(dateTime$)

    if lcase(scheduledEventXML.recurrenceGoesForever.GetText()) = "true" then
        scheduledEventBS.recurrenceGoesForever = true
    else
        scheduledEventBS.recurrenceGoesForever = false
    endif
    
    dateTime$ = scheduledEventXML.recurrenceEndDate.GetText()    
    recurrenceEndDate = FixDateTime(dateTime$)
    recurrenceEndDate.AddSeconds(60 * 60 * 24) ' adjust the recurrence end date to refer to the beginning of the next day
    scheduledEventBS.recurrenceEndDate = recurrenceEndDate
            
    return scheduledEventBS    
    
End Function


' required format looks like
'		2012-10-03T15:49:00
Function FixDateTime(dateTime$ As String) As Object

    dateTime = CreateObject("roDateTime")
    
    ' strip '-' and ':' so that BrightSign can parse the dateTime properly
    index = instr(1, dateTime$, "-")
    while index > 0
        
        a$ = mid(dateTime$, 1, index - 1)
        b$ = mid(dateTime$, index + 1)
        dateTime$ = a$ + b$

        index = instr(1, dateTime$, "-")
        
    end while

    index = instr(1, dateTime$, ":")
    while index > 0
        
        a$ = mid(dateTime$, 1, index - 1)
        b$ = mid(dateTime$, index + 1)
        dateTime$ = a$ + b$

        index = instr(1, dateTime$, ":")
        
    end while

	if not dateTime.FromIsoString(dateTime$) then
		return Invalid
	endif

    return dateTime
        
End Function


Function GetActiveScheduledEvent() As Object

'   determine if there is a scheduled event that should be active at this time

systemTime = CreateObject("roSystemTime")    
eventDateTime = systemTime.GetLocalDateTime()
' print "GetActiveScheduledEvent() called on zone ";zone.name$;" at ";eventDateTime.GetString()
systemTime = 0

    activeScheduledEvent = 0

    for each scheduledEvent in m.scheduledEvents
    
'       is there a playlist that should be active now based on the scheduledEvent?

        if scheduledEvent.allDayEveryDay then
        
            activeScheduledEvent = scheduledEvent
            exit for
            
        endif
                         
'       is the current scheduledEvent active today? if no, go to next scheduledEvent

        eventDateTime = scheduledEvent.dateTime
        systemTime = CreateObject("roSystemTime")
        currentDateTime = systemTime.GetLocalDateTime()

        scheduledEventActiveToday = false
        
'       if it's not a recurring event and its start date is today, then it is active today

        if not scheduledEvent.recurrence then
        
            if eventDateTime.GetYear() = currentDateTime.GetYear() and eventDateTime.GetMonth() = currentDateTime.GetMonth() and eventDateTime.GetDay() = currentDateTime.GetDay() then
               scheduledEventActiveToday = true
            endif
            
        endif
        
        if (not scheduledEventActiveToday) and scheduledEvent.recurrence then
        
'           determine if the date represented by the scheduled event is within the recurrence range

            dateWithinRange = false
            if scheduledEvent.recurrenceStartDate.GetString() < currentDateTime.GetString() then
            
                if scheduledEvent.recurrenceGoesForever then
                    dateWithinRange = true
                else if scheduledEvent.recurrenceEndDate.GetString() >= currentDateTime.GetString() then
                    dateWithinRange = true
                endif
                
            endif
                            
'           if it is within the range, check the recurrence pattern

            if dateWithinRange then
            
                if scheduledEvent.recurrencePattern$ = "Daily" then
                
                    if scheduledEvent.recurrencePatternDaily$ = "EveryDay" then
            
                        scheduledEventActiveToday = true
                        
                    else if scheduledEvent.recurrencePatternDaily$ = "EveryWeekday" then
                    
                        if currentDateTime.GetDayOfWeek() > 0 and currentDateTime.GetDayOfWeek() < 6 then
                        
                            scheduledEventActiveToday = true
                        
                        endif
                    
                    else ' EveryWeekend
                    
                        if currentDateTime.GetDayOfWeek() = 0 or currentDateTime.GetDayOfWeek() = 6 then
                        
                            scheduledEventActiveToday = true
                            
                        endif
                        
                    endif
                    
                else ' Weekly
                
                    bitwiseDaysOfWeek% = scheduledEvent.recurrencePatternDaysOfWeek%
                    currentDayOfWeek = currentDateTime.GetDayOfWeek()
                    bitDayOfWeek% = 2 ^ currentDayOfWeek
                    if (bitwiseDaysOfWeek% and bitDayOfWeek%) <> 0 then
                        scheduledEventActiveToday = true
                    endif
                                        
                endif
                                
            endif
            
        endif

'           see if the currentScheduledEvent should be active right now
'               it will be active right now if its start time < current start time and its end time > current start time

        if scheduledEventActiveToday then
        
            eventTodayStartTime = systemTime.GetLocalDateTime()
            eventTodayStartTime.SetHour(scheduledEvent.dateTime.GetHour())
            eventTodayStartTime.SetMinute(scheduledEvent.dateTime.GetMinute())
            eventTodayStartTime.SetSecond(scheduledEvent.dateTime.GetSecond())
            eventTodayStartTime.SetMillisecond(0)
            
            eventTodayEndTime = systemTime.GetLocalDateTime()
            eventTodayEndTime.SetHour(scheduledEvent.dateTime.GetHour())
            eventTodayEndTime.SetMinute(scheduledEvent.dateTime.GetMinute())
            eventTodayEndTime.SetSecond(scheduledEvent.dateTime.GetSecond())
            eventTodayEndTime.SetMillisecond(0)
            eventTodayEndTime.AddSeconds(scheduledEvent.duration% * 60)
            
            if eventTodayStartTime.GetString() <= currentDateTime.GetString() and eventTodayEndTime.GetString() > currentDateTime.GetString() then
                
                activeScheduledEvent = scheduledEvent
                activeScheduledEvent.dateTime = eventTodayStartTime
                
'                print "at end, eventDateTime = ";eventDateTime.GetString()
'                print "at end, currentDateTime = ";currentDateTime.GetString()

                exit for
                
            endif
            
        endif

    next
    
    return activeScheduledEvent
    
End Function    


Function GetNextScheduledEventTime() As Object

    dim futureScheduledEvents[10]
    dim futureScheduledEventStartTimes[10]
    
    nextScheduledEventTime = CreateObject("roDateTime")
    
    ' for each scheduled event, see if it could start in the future. If yes, determine the earliest
    ' future start time that is later than now. Store the scheduled event and that start time.
    ' Use the scheduled event in that list with the lowest start time.
    
    for each scheduledEvent in m.scheduledEvents
    
        if scheduledEvent.allDayEveryDay then
        
            ' an allDayEveryDay event is always active, so by definition, it is not a future event.
            goto endLoop
            
        endif

        eventDateTime = scheduledEvent.dateTime
        systemTime = CreateObject("roSystemTime")
        currentDateTime = systemTime.GetLocalDateTime()

'       if it's not a recurring event and its start date/time is in the future, then it is eligible

        if not scheduledEvent.recurrence then
        
            if eventDateTime.GetString() > currentDateTime.GetString() then
                
                futureScheduledEvents.push(scheduledEvent)
                futureScheduledEventStartTimes.push(eventDateTime)
                goto endLoop
                
            endif
            
        endif
        
'       if it's a recurring event, see if its date range includes the future

        if scheduledEvent.recurrence then
        
            eventToday = CreateObject("roDateTime")
            eventToday.SetYear(currentDateTime.GetYear())
            eventToday.SetMonth(currentDateTime.GetMonth())
            eventToday.SetDay(currentDateTime.GetDay())
            eventToday.SetHour(eventDateTime.GetHour())
            eventToday.SetMinute(eventDateTime.GetMinute())

            if scheduledEvent.recurrenceGoesForever or scheduledEvent.recurrenceEndDate.GetString() > currentDateTime.GetString() then
        
'               find the earliest time > now that this recurring event could start

                if scheduledEvent.recurrencePattern$ = "Daily" then
                
                    if scheduledEvent.recurrencePatternDaily$ = "EveryDay" then
            
                        
                        if eventToday.GetString() > currentDateTime.GetString() then
                        
                            futureScheduledEvents.push(scheduledEvent)
                            futureScheduledEventStartTimes.push(eventToday)
                            goto endLoop
                        
                        else ' use the next day
                        
                            eventToday.AddSeconds(60 * 60 * 24)
                            futureScheduledEvents.push(scheduledEvent)
                            futureScheduledEventStartTimes.push(eventToday)
                            goto endLoop
                            
                        endif
                        
                    else if scheduledEvent.recurrencePatternDaily$ = "EveryWeekday" then
                        ' if today is a weekday, proceed as in the case above, except that instead of using
                        ' the 'next day', use the 'next weekday' (which may or may not be the next day) for the test
                        
                        if currentDateTime.GetDayOfWeek() > 0 and currentDateTime.GetDayOfWeek() < 6 then
                            
                            ' current day is a weekday
                            
                            if eventToday.GetString() > currentDateTime.GetString() then
                            
                                futureScheduledEvents.push(scheduledEvent)
                                futureScheduledEventStartTimes.push(eventToday)
                                goto endLoop
                        
                            else
                                
                                ' if today is Friday, add 3 days
                                daysToAdd% = 1
                                if currentDateTime.GetDayOfWeek() = 5 then daysToAdd% = 3
                                eventToday.AddSeconds(60 * 60 * 24 * daysToAdd%)
                                futureScheduledEvents.push(scheduledEvent)
                                futureScheduledEventStartTimes.push(eventToday)
                                goto endLoop
                                
                            endif
                            
                        else ' current day is a weekend
                            
                            ' if today is not a weekday, the next weekday (Monday) is the future event
                            daysToAdd% = 1
                            if currentDateTime.GetDayOfWeek() = 6 then daysToAdd% = 2
                            eventToday.AddSeconds(60 * 60 * 24 * daysToAdd%)
                            futureScheduledEvents.push(scheduledEvent)
                            futureScheduledEventStartTimes.push(eventToday)
                            goto endLoop
                            
                        endif
                    
                    else ' EveryWeekend
                        ' if today is a weekend, proceed as in the case above, except that instead of using
                        ' the 'next day', use the 'next weekend' (which may or may not be the next day) for the test

                        if currentDateTime.GetDayOfWeek() = 0 or currentDateTime.GetDayOfWeek() = 6 then
                            
                            ' current day is a weekend
                            
                            if eventToday.GetString() > currentDateTime.GetString() then
                            
                                futureScheduledEvents.push(scheduledEvent)
                                futureScheduledEventStartTimes.push(eventToday)
                                goto endLoop
                        
                            else
                                
                                ' if today is Sunday, add 6 days
                                daysToAdd% = 1
                                if currentDateTime.GetDayOfWeek() = 5 then daysToAdd% = 6
                                eventToday.AddSeconds(60 * 60 * 24 * daysToAdd%)
                                futureScheduledEvents.push(scheduledEvent)
                                futureScheduledEventStartTimes.push(eventToday)
                                goto endLoop
                                
                            endif
                            
                        else ' current day is a weekday
                            
                            ' if today is not a weekday, the next weekday (Monday) is the future event
                            daysToAdd% = 6 - currentDateTime.GetDayOfWeek()
                            eventToday.AddSeconds(60 * 60 * 24 * daysToAdd%)
                            futureScheduledEvents.push(scheduledEvent)
                            futureScheduledEventStartTimes.push(eventToday)
                            goto endLoop
                            
                        endif
                        
                    endif        
        
                else ' Weekly
                
                    ' if today is one of the days specified, test against today. if the test fails,
                    ' or today is not one of the days specified, find the next specified day and use it.
                    
                    bitwiseDaysOfWeek% = scheduledEvent.recurrencePatternDaysOfWeek%
                    currentDayOfWeek = currentDateTime.GetDayOfWeek()
                    bitDayOfWeek% = 2 ^ currentDayOfWeek
                    if (bitwiseDaysOfWeek% and bitDayOfWeek%) <> 0 then
                    
                        if eventToday.GetString() > currentDateTime.GetString() then
                        
                            futureScheduledEvents.push(scheduledEvent)
                            futureScheduledEventStartTimes.push(eventToday)
                            goto endLoop
                            
                        endif
                    
                    endif
                        
                    ' find the next specified day and use it    
                    if bitwiseDaysOfWeek% <> 0 then
                    
                        while true
                            currentDayOfWeek = currentDayOfWeek + 1
                            if currentDayOfWeek >= 7 then currentDayOfWeek = 0
                            bitDayOfWeek% = 2 ^ currentDayOfWeek
                            eventToday.AddSeconds(60 * 60 * 24)
                            if (bitwiseDaysOfWeek% and bitDayOfWeek%) <> 0 then
                                futureScheduledEvents.push(scheduledEvent)
                                futureScheduledEventStartTimes.push(eventToday)
                                goto endLoop
                            endif
                        end while        
                        
                    endif

                endif
                
            endif
            
        endif        

endLoop:

    next
    
    ' sort the future events
    dim sortedFutureEventTimes[10]
    if futureScheduledEventStartTimes.Count() > 1 then
        SortFutureScheduledEvents(futureScheduledEventStartTimes, sortedFutureEventTimes)
        nextScheduledEventTime = futureScheduledEventStartTimes[sortedFutureEventTimes[0]]
    else
        nextScheduledEventTime = futureScheduledEventStartTimes[0]
    endif
        
    return nextScheduledEventTime
    
End Function


Sub SortFutureScheduledEvents(futureEventTimes As Object, sortedIndices As Object)

    ' initialize array with indices.
    for i% = 0 to futureEventTimes.Count()-1
        sortedIndices[i%] = i%
    next

    numItemsToSort% = futureEventTimes.Count()

    for i% = numItemsToSort% - 1 to 1 step -1
        for j% = 0 to i%-1
	        index0 = sortedIndices[j%]
	        time0 = futureEventTimes[index0].GetString()
            index1 = sortedIndices[j%+1]
            time1 = futureEventTimes[index1].GetString()
            if time0 > time1 then
                k% = sortedIndices[j%]
                sortedIndices[j%] = sortedIndices[j%+1]
                sortedIndices[j%+1] = k%
            endif
        next
    next

    return
    
End Sub

'endregion

'region StartPlayback and CreateObjects
Sub StartPlayback()

    sign = m.sign
    
    ' set a default udp receive port
    m.udpReceivePort = sign.udpReceivePort
    m.udpSendPort = sign.udpSendPort
    m.udpAddress$ = sign.udpAddress$
    m.udpAddressType$ = sign.udpAddressType$

    EnableZoneSupport(true)

    ' kick off playback

	m.diagnostics.PrintTimestamp()
	m.diagnostics.PrintDebug("### set background screen color")

	' set background screen color
	if type(sign.backgroundScreenColor%) = "roInt" then
		videoMode = CreateObject("roVideoMode")
		videoMode.SetBackgroundColor(sign.backgroundScreenColor%)                     
		videoMode = invalid
	endif

	' unmute all audio explicitly for Cheetah / Panther / Puma
	m.UnmuteAllAudio()

	numZones% = sign.zonesHSM.Count()
	if numZones% > 0 then

		' construct zones
		for i% = 0 to numZones% - 1
			zoneHSM = sign.zonesHSM[i%]
			if type(zoneHSM.playlist) = "roAssociativeArray" then
				m.diagnostics.PrintTimestamp()
				m.diagnostics.PrintDebug("### Constructor zone")
				zoneHSM.Constructor()
			endif
		next  
		
		' launch the zones      
		for i% = 0 to numZones% - 1
			zoneHSM = sign.zonesHSM[i%]
			if type(zoneHSM.playlist) = "roAssociativeArray" then
				m.diagnostics.PrintTimestamp()
				m.diagnostics.PrintDebug("### Launch playback")
				zoneHSM.Initialize()
			endif
		next        
	endif
	
End Sub


' m is the zone
Sub CreateObjects()

	zoneHSM = m
	
	' is there any harm in creating a keyboard object even if it is not used?
    if type(m.bsp.keyboard) <> "roKeyboard" then
        m.bsp.keyboard = CreateObject("roKeyboard")
        m.bsp.keyboard.SetPort(m.bsp.msgPort)
    endif
		                        
	for each key in zoneHSM.stateTable
    
		state = zoneHSM.stateTable[key]

		if state.type$ = "tripleUSB" then
            m.CreateSerial(m.bsp, state.tripleUSBPort$, false)
            if IsString(state.boseProductPort$) and state.boseProductPort$ <> "" then
	            m.CreateSerial(m.bsp, state.boseProductPort$, true)
	        endif
		endif
		    
        gpioEvents = state.gpioEvents
        for each gpioEventNumber in gpioEvents
            if type(gpioEvents[gpioEventNumber]) = "roAssociativeArray" then
                m.CreateObjectsNeededForTransitionCommands(gpioEvents[gpioEventNumber])
            endif
        next

		for buttonPanelIndex% = 0 to 2
			bpEvents = state.bpEvents[buttonPanelIndex%]
			for each bpEventNumber in bpEvents
				if type(bpEvents[bpEventNumber]) = "roAssociativeArray" then
					m.CreateObjectsNeededForTransitionCommands(bpEvents[bpEventNumber])
				endif
			next
		next                

        if type(state.mstimeoutEvent) = "roAssociativeArray"
            m.CreateObjectsNeededForTransitionCommands(state.mstimeoutEvent)
        endif
        
		if type(state.timeClockEvents) = "roArray" then
			for each timeClockEvent in state.timeClockEvents
	            m.CreateObjectsNeededForTransitionCommands(timeClockEvent.transition)
			next
		endif

        if type(state.videoEndEvent) = "roAssociativeArray"
            m.CreateObjectsNeededForTransitionCommands(state.videoEndEvent)
        endif
                
        if type(state.audioEndEvent) = "roAssociativeArray"
            m.CreateObjectsNeededForTransitionCommands(state.audioEndEvent)
        endif

        if type(state.keyboardEvents) = "roAssociativeArray" or type(state.usbStringEvents) = "roAssociativeArray" then
            
            if type(state.keyboardEvents) = "roAssociativeArray" then
                keyboardEvents = state.keyboardEvents
                for each keyboardEvent in state.keyboardEvents
                    if type(keyboardEvents[keyboardEvent]) = "roAssociativeArray" then
                        m.CreateObjectsNeededForTransitionCommands(keyboardEvents[keyboardEvent])
                    endif
                next
            endif                    

            if type(state.usbStringEvents) = "roAssociativeArray"
                usbEvents = state.usbStringEvents
                for each usbEvent in state.usbEvents
                    if type(usbEvents[usbEvent]) = "roAssociativeArray" then
                        m.CreateObjectsNeededForTransitionCommands(usbEvents[usbEvent])
                    endif
                next                        
            endif
            
        endif
            
        if type(state.remoteEvents) = "roAssociativeArray" then
        
            if type(m.bsp.remote) <> "roIRRemote" then
                m.bsp.remote = CreateObject("roIRRemote")
                m.bsp.remote.SetPort(m.bsp.msgPort)
            endif
        
            remoteEvents = state.remoteEvents
            for each remoteEvent in state.remoteEvents
                m.CreateObjectsNeededForTransitionCommands(remoteEvents[remoteEvent])                      
            next
        
        endif

		if type(state.usbBinaryEtapEvents) = "roArray" then

			if type(m.usbBinaryEtap) <> "roUsbBinaryEtap" then
				m.bsp.usbBinaryEtap = CreateObject("roUsbBinaryEtap", 0)
                m.bsp.usbBinaryEtap.SetPort(m.bsp.msgPort)
			endif

            for each usbBinaryEtapInputTransitionSpec in state.usbBinaryEtapEvents
                m.CreateObjectsNeededForTransitionCommands(usbBinaryEtapInputTransitionSpec.transition)                      
            next
		
		endif

		if (type(state.gpsEnterRegionEvents) = "roArray" and state.gpsEnterRegionEvents.Count() > 0) or (type(state.gpsExitRegionEvents) = "roArray" and state.gpsExitRegionEvents.Count() > 0) then
			m.CreateSerial(m.bsp, m.bsp.gpsPort$, false)
		endif

        serialEvents = state.serialEvents
        for each serialPort in serialEvents

            m.CreateSerial(m.bsp, serialPort, false)

			port% = int(val(serialPort))
			serialPortConfiguration = m.bsp.sign.serialPortConfigurations[port%]
			protocol$ = serialPortConfiguration.protocol$
			
			if protocol$ = "Binary" then
				if type(serialEvents[serialPort]) = "roAssociativeArray" then
					if type(serialEvents[serialPort].streamInputTransitionSpecs) = "roArray" then
						for each streamInputTransitionSpec in serialEvents[serialPort].streamInputTransitionSpecs
							m.CreateObjectsNeededForTransitionCommands(streamInputTransitionSpec.transition)
						next
					endif
				endif
			else
				for each serialEvent in serialEvents[serialPort]
					m.CreateObjectsNeededForTransitionCommands(serialEvents[serialPort][serialEvent])
				next
            endif
        next

		if type(state.zoneMessageEvents) = "roAssociativeArray" then

            for each zoneMessageEvent in state.zoneMessageEvents
                m.CreateObjectsNeededForTransitionCommands(state.zoneMessageEvents[zoneMessageEvent])                      
            next
		
		endif
		

		if type(state.internalSynchronizeEvents) = "roAssociativeArray" then

            for each internalSynchronizeEvent in state.internalSynchronizeEvents
                m.CreateObjectsNeededForTransitionCommands(state.internalSynchronizeEvents[internalSynchronizeEvent])                      
            next
		
		endif
		
		createDatagramReceiver = false
		if state.type$ = "rfInputChannel" then
			if type(state.channelUpEvent) = "roAssociativeArray" and IsString(state.channelUpEvent.udpUserEvent$) createDatagramReceiver = true
			if type(state.channelDownEvent) = "roAssociativeArray" and IsString(state.channelDownEvent.udpUserEvent$) createDatagramReceiver = true
		endif

        if type(state.udpEvents) = "roAssociativeArray" or type(state.synchronizeEvents) = "roAssociativeArray" or createDatagramReceiver then
            
			createDatagramReceiver = false

			if type(m.bsp.udpReceiver) <> "roDatagramReceiver" then
				createDatagramReceiver = true
			else
				if type(m.bsp.existingUdpReceivePort) = "roInt" and m.bsp.existingUdpReceivePort <> m.bsp.udpReceivePort then
					createDatagramReceiver = true
				endif
			endif

			if createDatagramReceiver then
                m.bsp.udpReceiver = CreateObject("roDatagramReceiver", m.bsp.udpReceivePort)
                m.bsp.udpReceiver.SetPort(m.bsp.msgPort)
				m.bsp.existingUdpReceivePort = m.bsp.udpReceivePort
            endif
            
            if type(state.udpEvents) = "roAssociativeArray" then
                udpEvents = state.udpEvents
                for each udpEvent in state.udpEvents
                    m.CreateObjectsNeededForTransitionCommands(udpEvents[udpEvent])                      
                next
            endif
            
            if type(state.synchronizeEvents) = "roAssociativeArray" then
                synchronizeEvents = state.synchronizeEvents
                for each synchronizeEvent in state.synchronizeEvents
                    m.CreateObjectsNeededForTransitionCommands(synchronizeEvents[synchronizeEvent])                      
                next
            endif
            
        endif
        
		if state.type$ = "html5" and state.enableMouseEvents then
            m.bsp.InitializeTouchScreen(zoneHSM)
		endif
		                                         
        if type(state.touchEvents) = "roAssociativeArray" then
            m.bsp.InitializeTouchScreen(zoneHSM)
                        
            for each eventNum in state.touchEvents
                m.bsp.AddRectangularTouchRegion(m, state.touchEvents[eventNum], val(eventNum))
                m.CreateObjectsNeededForTransitionCommands(state.touchEvents[eventNum])                      
            next
        endif
                
        if type(state.videoTimeCodeEvents) = "roAssociativeArray" then
            for each eventNum in state.videoTimeCodeEvents
                m.CreateObjectsNeededForTransitionCommands(state.videoTimeCodeEvents[eventNum])                      
            next
        endif
                                
		if type(state.cmds) = "roArray" then
			for each cmd in state.cmds
				commandName$ = cmd.name$
                if commandName$ = "sendUDPCommand" or commandName$ = "synchronize" then
                    m.CreateUDPSender(m.bsp)
                else if commandName$ = "sendSerialStringCommand" or commandName$ = "sendSerialBlockCommand" or commandName$ = "sendSerialByteCommand" or commandName$ = "sendSerialBytesCommand" then
					port$ = cmd.parameters["port"].GetCurrentParameterValue()
					m.CreateSerial(m.bsp, port$, true)
                endif
			next
		endif
            
	next

End Sub


Sub CreateObjectsNeededForTransitionCommands(transition As Object)

    if type(transition.transitionCmds) = "roArray" then
        for each cmd in transition.transitionCmds
			m.CreateObjectForTransitionCommand(cmd)
        next
    endif

	if type(transition.conditionalTargets) = "roArray" then
		for each conditionalTarget in transition.conditionalTargets
			if type(conditionalTarget.transitionCmds) = "roArray" then
				for each cmd in conditionalTarget.transitionCmds
					m.CreateObjectForTransitionCommand(cmd)
				next
			endif
		next
	endif

End Sub


Sub CreateObjectForTransitionCommand(cmd As Object)

    commandName$ = cmd.name$
    if commandName$ = "sendUDPCommand" or commandName$ = "synchronize" then
        m.CreateUDPSender(m.bsp)
    else if commandName$ = "sendSerialStringCommand" or commandName$ = "sendSerialBlockCommand" or commandName$ = "sendSerialByteCommand" or commandName$ = "sendSerialBytesCommand" then
		port$ = cmd.parameters["port"].GetCurrentParameterValue()
		m.CreateSerial(m.bsp, port$, true)
    endif

End Sub


Sub ConfigureBPs()

	m.bpOutput = CreateObject("roArray", 3, true)
	m.bpOutputSetup = CreateObject("roArray", 3, true)
	
	m.ConfigureBP(0, "TouchBoard-0-LED", "TouchBoard-0-LED-SETUP")
	m.ConfigureBP(1, "TouchBoard-1-LED", "TouchBoard-1-LED-SETUP")
	m.ConfigureBP(2, "TouchBoard-2-LED", "TouchBoard-2-LED-SETUP")
	
End Sub


Sub ConfigureBP(buttonPanelIndex% As Integer, touchBoardLED$ As String, touchBoardLEDSetup$ As String)
	if type(m.bpInputPorts[buttonPanelIndex%]) = "roControlPort" then
		if type(m.bpOutput[buttonPanelIndex%]) <> "roControlPort" then
			m.diagnostics.PrintDebug("Creating bpOutput")
			m.bpOutput[buttonPanelIndex%] = CreateObject("roControlPort", touchBoardLED$)
			if type(m.bpOutput[buttonPanelIndex%]) = "roControlPort" then
				m.bpOutputSetup[buttonPanelIndex%] = CreateObject("roControlPort", touchBoardLEDSetup$)
				if type(m.bpOutputSetup[buttonPanelIndex%]) = "roControlPort" then
					m.bpOutputSetup[buttonPanelIndex%].SetOutputValue(0, 22)
				endif
			endif
		endif
	endif
End Sub


Sub CreateUDPSender(bsp As Object)

	createDatagramSender = false

	if type(bsp.udpSender) <> "roDatagramSender" then
		createDatagramSender = true
	else
		if (type(bsp.existingUdpAddressType$) = "roString" and bsp.existingUdpAddressType$ <> bsp.udpAddressType$) or (type(bsp.existingUdpAddress$) = "roString" and bsp.existingUdpAddress$ <> bsp.udpAddress$) or (type(bsp.existingUdpSendPort) = "roInt" and bsp.existingUdpSendPort <> bsp.udpSendPort) then
			createDatagramSender = true
		endif
	endif

	if createDatagramSender then
        bsp.diagnostics.PrintDebug("Creating roDatagramSender")
        bsp.udpSender = CreateObject("roDatagramSender")
		if bsp.udpAddressType$ = "LocalSubnet" then
			bsp.udpSender.SetDestination("BCAST-LOCAL-SUBNETS", bsp.udpSendPort)
        else
			bsp.udpSender.SetDestination(bsp.udpAddress$, bsp.udpSendPort)
		endif

		bsp.existingUdpAddressType$ = bsp.udpAddressType$
		bsp.existingUdpAddress$ = bsp.udpAddress$
		bsp.existingUdpSendPort = bsp.udpSendPort

    endif
    
End Sub


Sub CreateSerial(bsp As Object, port$ As String, outputOnly As Boolean)

    if type(bsp.serial) <> "roAssociativeArray" then
        bsp.serial = CreateObject("roAssociativeArray")
    endif

    port% = int(val(port$))
    serialPortConfiguration = bsp.serialPortConfigurations[port%]
    serialPortSpeed% = serialPortConfiguration.serialPortSpeed%
    serialPortMode$ = serialPortConfiguration.serialPortMode$    
      
    if type(bsp.serial[port$]) = "roSerialPort" then
		serial = bsp.serial[port$]
	else
		serial = CreateObject("roSerialPort", port%, serialPortSpeed%)
	    if type(serial) <> "roSerialPort" then 
		    bsp.diagnostics.PrintDebug("Error creating roSerialPort " + port$)
			return
	    endif
	endif
    
    ok = serial.SetMode(serialPortMode$)
    if not ok then print "Error setting serial mode" : stop
    
    protocol$ = serialPortConfiguration.protocol$
    sendEol$ = serialPortConfiguration.sendEol$
    receiveEol$ = serialPortConfiguration.receiveEol$
    
	serial.SetSendEol(sendEol$)
	serial.SetReceiveEol(receiveEol$)
	
	if serialPortConfiguration.invertSignals then
		serial.SetInverted(1)
	else
		serial.SetInverted(0)
	endif
	
    serial.SetUserData(port$)

    bsp.serial[port$] = serial
        
    if not outputOnly then
		if protocol$ = "Binary" then
			serial.SetByteEventPort(m.msgPort)
		else
			serial.SetLineEventPort(m.msgPort)
		endif
	endif
	
End Sub


Function IsString(inputVariable As Object) As Boolean

	if type(inputVariable) = "roString" or type(inputVariable) = "String" then return true
	return false
	
End Function


Function IsInteger(inputVariable As Object) As Boolean

	if type(inputVariable) = "roInt" or type(inputVariable) = "Integer" then return true
	return false
	
End Function


Function GetEolFromSpec(eolSpec$ As String) As String

    eol$ = chr(13)
    if eolSpec$ = "LF" then
	    eol$ = chr(10)
    else if eolSpec$ = "CR+LF" then
	    eol$ = chr(13) + chr(10)
    endif

	return eol$

End Function

'endregion

'region newSign
Function newSign(BrightAuthor As Object, globalVariables As Object, bsp As Object, msgPort As Object, controlPort As Object, version% As Integer) As Object

' check for compatibility - Panther / Cheetah presentations won't play on other families
	publishedModel$ = BrightAuthor.meta.model.GetText()
	if publishedModel$ = "XD230" or publishedModel$ = "XD1030" or publishedModel$ = "XD1230" or publishedModel$ = "HD120" or publishedModel$ = "HD220" or publishedModel$ = "HD1020" or publishedModel$ = "AU320" then
		if bsp.sysInfo.deviceFamily$ <> "cheetah" and bsp.sysInfo.deviceFamily$ <> "panther" then
			DisplayIncompatibleModelMessage(publishedModel$, bsp.sysInfo.deviceModel$)
		endif
	endif

' determine whether this presentation could use new or old parameters (a Panther might use either)
	bsp.currentPresentationUsesRoAudioOutputParameters = true
	if publishedModel$ = "HD110" or publishedModel$ = "HD210" or publishedModel$ = "HD410" or publishedModel$ = "HD810" or publishedModel$ = "HD910" or publishedModel$ = "HD912" or publishedModel$ = "A913" or publishedModel$ = "A933" or publishedModel$ = "HD960" or publishedModel$ = "HD962" or publishedModel$ = "TD1012" or publishedModel$ = "HD1010" then
		bsp.currentPresentationUsesRoAudioOutputParameters = false
	endif

' reset variable
	bsp.mediaListInactivity = invalid

    Sign = CreateObject("roAssociativeArray")
    
    Sign.numTouchEvents% = 0
    Sign.numVideoTimeCodeEvents% = 0
    
    ' get sign data

    Sign.name$ = BrightAuthor.meta.name.GetText()
    if not IsString(Sign.name$) then print "Invalid XML file - meta name not found" : stop
    
	Sign.videoMode$ = BrightAuthor.meta.videoMode.GetText()
	if Sign.videoMode$ <> "not applicable" then
		if not IsString(Sign.videoMode$) then print "Invalid XML file - meta videoMode not found" : stop
	'    print "Video mode is ";Sign.videoMode$
    
		videoMode = CreateObject("roVideoMode")
		ok = videoMode.SetMode(Sign.videoMode$)
		if ok = 0 then print "Error: Can't set VIDEOMODE to ::"; videoMode$; "::" : stop
		videoMode = invalid
    
		Sign.videoConnector$ = BrightAuthor.meta.videoConnector.GetText()
		if not IsString(Sign.videoConnector$) then print "Invalid XML file - meta videoConnector not found" : stop  
	'    print "Video connector is ";Sign.videoConnector$
	endif

    Sign.timezone$ = BrightAuthor.meta.timezone.GetText()
    if IsString(Sign.timezone$) then
        bsSystemTime = CreateObject("roSystemTime")
        if Sign.timezone$ <> "" then
            bsSystemTime.SetTimeZone(Sign.timezone$)
        endif
        bsSystemTime = 0
    endif
    
    rssDownloadSpec = BrightAuthor.meta.rssDownloadSpec
	Sign.rssDownloadPeriodicValue% = GetRSSDownloadInterval(rssDownloadSpec)
    
	Sign.deviceWebPageDisplay$ = "Standard"
    if BrightAuthor.meta.deviceWebPageDisplay.GetText() <> "" then
		Sign.deviceWebPageDisplay$ = BrightAuthor.meta.deviceWebPageDisplay.GetText()
	endif
    Sign.customDeviceWebPage$ = BrightAuthor.meta.customDeviceWebPage.GetText()

    backgroundScreenColor = BrightAuthor.meta.backgroundScreenColor
    Sign.backgroundScreenColor% = GetColor(backgroundScreenColor.GetAttributes())
    
    Sign.languageKey$ = BrightAuthor.meta.languageKey.GetText()
    globalVariables.language$ = Sign.languageKey$

    Sign.serialPortConfigurations = CreateObject("roArray", 6, true)
    
	bp900AConfigureAutomatically = GetBoolFromString(BrightAuthor.meta.BP900AConfigureAutomatically.GetText(), true)
	bp900BConfigureAutomatically = GetBoolFromString(BrightAuthor.meta.BP900BConfigureAutomatically.GetText(), true)
	bp900CConfigureAutomatically = GetBoolFromString(BrightAuthor.meta.BP900CConfigureAutomatically.GetText(), true)
	bp200AConfigureAutomatically = GetBoolFromString(BrightAuthor.meta.BP200AConfigureAutomatically.GetText(), true)
	bp200BConfigureAutomatically = GetBoolFromString(BrightAuthor.meta.BP200BConfigureAutomatically.GetText(), true)
	bp200CConfigureAutomatically = GetBoolFromString(BrightAuthor.meta.BP200CConfigureAutomatically.GetText(), true)

	bp900AConfiguration% = GetIntFromString(BrightAuthor.meta.BP900AConfiguration.GetText())
	bp900BConfiguration% = GetIntFromString(BrightAuthor.meta.BP900BConfiguration.GetText())
	bp900CConfiguration% = GetIntFromString(BrightAuthor.meta.BP900CConfiguration.GetText())
	bp200AConfiguration% = GetIntFromString(BrightAuthor.meta.BP200AConfiguration.GetText())
	bp200BConfiguration% = GetIntFromString(BrightAuthor.meta.BP200BConfiguration.GetText())
	bp200CConfiguration% = GetIntFromString(BrightAuthor.meta.BP200CConfiguration.GetText())

	if type(bsp.bpInputPorts[0]) = "roControlPort" then
		bsp.bpInputPortConfigurations[0] = GetBPConfiguration(bsp.bpInputPortHardware[0], bp900AConfigureAutomatically, bp900AConfiguration%, bp200AConfigureAutomatically, bp200AConfiguration%)
	endif

	if type(bsp.bpInputPorts[1]) = "roControlPort" then
		bsp.bpInputPortConfigurations[1] = GetBPConfiguration(bsp.bpInputPortHardware[1], bp900BConfigureAutomatically, bp900BConfiguration%, bp200BConfigureAutomatically, bp200BConfiguration%)
	endif

	if type(bsp.bpInputPorts[2]) = "roControlPort" then
		bsp.bpInputPortConfigurations[2] = GetBPConfiguration(bsp.bpInputPortHardware[2], bp900CConfigureAutomatically, bp900CConfiguration%, bp200CConfigureAutomatically, bp200CConfiguration%)
	endif

	bsp.gpsConfigured = false
	bsp.gpsLocation = { latitude: invalid, longitude: invalid }
	bsp.gpsPort$ = ""

    if BrightAuthor.meta.baudRate.Count() = 1 then
        ' old format
        serialPortSpeed% = int(val(BrightAuthor.meta.baudRate.GetText()))
        serialPortMode$ = BrightAuthor.meta.dataBits.GetText() + BrightAuthor.meta.parity.GetText() + BrightAuthor.meta.stopBits.GetText()
        serialPortConfiguration = CreateObject("roAssociativeArray")
        serialPortConfiguration.serialPortSpeed% = serialPortSpeed%
        serialPortConfiguration.serialPortMode$ = serialPortMode$
        serialPortConfiguration.sendEol$ = chr(13)
        serialPortConfiguration.receiveEol$ = chr(13)
        serialPortConfiguration.invertSignals = false
		serialPortConfiguration.gps = false
        Sign.serialPortConfigurations[0] = serialPortConfiguration
    else
        serialPortConfigurationsXML = BrightAuthor.meta.SerialPortConfiguration
        for each serialPortConfigurationXML in serialPortConfigurationsXML
            
            serialPortConfiguration = CreateObject("roAssociativeArray")

            serialPortSpeed% = int(val(serialPortConfigurationXML.baudRate.GetText()))
            serialPortConfiguration.serialPortSpeed% = serialPortSpeed%

            dataBits$ = serialPortConfigurationXML.dataBits.GetText()
            parity$ = serialPortConfigurationXML.parity.GetText()
            stopBits$ = serialPortConfigurationXML.stopBits.GetText()
            serialPortMode$ = dataBits$ + parity$ + stopBits$
            serialPortConfiguration.serialPortMode$ = serialPortMode$
            
            protocol$ = serialPortConfigurationXML.protocol.GetText()
            if protocol$ = "" then
	            serialPortConfiguration.protocol$ = "ASCII"
            else
	            serialPortConfiguration.protocol$ = serialPortConfigurationXML.protocol.GetText()
            endif
            
			serialPortConfiguration.sendEol$ = GetEolFromSpec(serialPortConfigurationXML.sendEol.GetText())
            serialPortConfiguration.receiveEol$ = GetEolFromSpec(serialPortConfigurationXML.receiveEol.GetText())
	        serialPortConfiguration.invertSignals = false
            if lcase(serialPortConfigurationXML.invertSignals.GetText()) = "true" then
				serialPortConfiguration.invertSignals = true
			endif

			port$ = serialPortConfigurationXML.port.GetText()
            port% = int(val(port$))

			connectedDevice$ = serialPortConfigurationXML.connectedDevice.GetText()
			if connectedDevice$ = "GPS" then
				serialPortConfiguration.gps = true
				bsp.gpsConfigured = true
				bsp.gpsPort$ = port$
			else
				serialPortConfiguration.gps = false
			endif
			                        
            Sign.serialPortConfigurations[port%] = serialPortConfiguration

        next    
    endif

' parse script plugins
    
	scriptPluginsContainer = BrightAuthor.meta.scriptPlugins

	if scriptPluginsContainer.Count() = 1 then

		scriptPluginsXML = scriptPluginsContainer.GetChildElements()

		for each scriptPluginXML in scriptPluginsXML
			scriptPlugin = newScriptPlugin(scriptPluginXML)
			bsp.scriptPlugins.push(scriptPlugin)
		next

	endif


' first pass parse of user variables

'	bsp.autoCreateMediaCounterVariables = GetBoolFromString(BrightAuthor.meta.autoCreateMediaCounterVariables.GetText(), false)

	bsp.networkedVariablesUpdateInterval% = 300
	networkedVariablesUpdateInterval$ = BrightAuthor.meta.networkedVariablesUpdateInterval.GetText()
	if networkedVariablesUpdateInterval$ <> "" then
        bsp.networkedVariablesUpdateInterval% = int(val(networkedVariablesUpdateInterval$))
	endif

	bsp.variablesDBExists = false

	userVariableSetXML = BrightAuthor.meta.userVariables
	if userVariableSetXML.Count() = 1 then

		userVariablesXML = userVariableSetXML.GetChildElements()

		if type(userVariablesXML) = "roXMLList" and userVariablesXML.Count() > 0 then
			bsp.ReadVariablesDB()
			bsp.currentDBSectionId% = bsp.GetDBSectionId(bsp.activePresentation$)
		endif

		for each userVariableXML in userVariablesXML
			if not bsp.userVariableSets.DoesExist(bsp.activePresentation$) then
				bsp.AddDBSection(bsp.activePresentation$)
				bsp.currentDBSectionId% = bsp.GetDBSectionId(bsp.activePresentation$)
				userVariables = CreateObject("roAssociativeArray")
				bsp.userVariableSets.AddReplace(bsp.activePresentation$, userVariables)
			else
				userVariables = bsp.userVariableSets.Lookup(bsp.activePresentation$)
			endif

			name$ = userVariableXML.name.GetText()

			if not userVariables.DoesExist(name$) then
				defaultValue$ = userVariableXML.defaultValue.GetText()
				bsp.AddDBVariable(name$, defaultValue$)
				userVariable = newUserVariable(bsp, name$, defaultValue$, defaultValue$)
				userVariables.AddReplace(name$, userVariable)
			else
				userVariable = userVariables.Lookup(name$)
			endif

			' if the user variable is specified with a system variable, set its value
			userVariable.systemVariable$ = userVariableXML.systemVariable.GetText()
			if userVariable.systemVariable$ = "serialNumber" then
				userVariable.SetCurrentValue(bsp.sysInfo.deviceUniqueID$, false)
			else if userVariable.systemVariable$ = "ipAddressWired" then
				userVariable.SetCurrentValue(bsp.sysInfo.ipAddressWired$, false)
			else if userVariable.systemVariable$ = "ipAddressWireless" then
				userVariable.SetCurrentValue(bsp.sysInfo.ipAddressWireless$, false)
			else if userVariable.systemVariable$ = "firmwareVersion" then
				userVariable.SetCurrentValue(bsp.sysInfo.deviceFWVersion$, false)
			else if userVariable.systemVariable$ = "scriptVersion" then
				userVariable.SetCurrentValue(bsp.sysInfo.autorunVersion$, false)
			else if userVariable.systemVariable$ = "rfChannelCount" then
				userVariable.SetCurrentValue(StripLeadingSpaces(stri(bsp.scannedChannels.Count())), false)
			else if userVariable.systemVariable$ = "edidMonitorSerialNumber" then
				userVariable.SetCurrentValue(bsp.sysInfo.edidMonitorSerialNumber$, false)
			else if userVariable.systemVariable$ = "edidYearOfManufacture" then
				userVariable.SetCurrentValue(bsp.sysInfo.edidYearOfManufacture$, false)
			else if userVariable.systemVariable$ = "edidMonitorName" then
				userVariable.SetCurrentValue(bsp.sysInfo.edidMonitorName$, false)
			else if userVariable.systemVariable$ = "edidManufacturer" then
				userVariable.SetCurrentValue(bsp.sysInfo.edidManufacturer$, false)
			else if userVariable.systemVariable$ = "edidUnspecifiedText" then
				userVariable.SetCurrentValue(bsp.sysInfo.edidUnspecifiedText$, false)
			else if userVariable.systemVariable$ = "edidSerialNumber" then
				userVariable.SetCurrentValue(bsp.sysInfo.edidSerialNumber$, false)
			else if userVariable.systemVariable$ = "edidManufacturerProductCode" then
				userVariable.SetCurrentValue(bsp.sysInfo.edidManufacturerProductCode$, false)
			else if userVariable.systemVariable$ = "edidWeekOfManufacture" then
				userVariable.SetCurrentValue(bsp.sysInfo.edidWeekOfManufacture$, false)
			endif

			' record networked information - parse in 2nd pass
			userVariable.url$ = ""
			userVariable.liveDataFeedName$ = ""

			url$ = userVariableXML.url.GetText()
			if url$ <> "" then
				userVariable.url$ = url$
			else
				if userVariableXML.liveDataFeedName.GetText() <> "" then
					userVariable.liveDataFeedName$ = userVariableXML.liveDataFeedName.GetText()
				endif
			endif
		next
	endif


' parse live data feeds
    
	liveDataFeedsContainer = BrightAuthor.meta.liveDataFeeds

	if liveDataFeedsContainer.Count() = 1 then

		liveDataFeedsXML = liveDataFeedsContainer.GetChildElements()

		for each liveDataFeedXML in liveDataFeedsXML
			liveDataFeed = newLiveDataFeed(bsp, liveDataFeedXML)
			bsp.liveDataFeeds.AddReplace(liveDataFeed.name$, liveDataFeed)
		next

	endif

' second pass parse of user variables

	if type(userVariables) = "roAssociativeArray" then
		for each userVariableKey in userVariables
			userVariable = userVariables.Lookup(userVariableKey)
			if type(userVariable.url$) <> "Invalid" and userVariable.url$ <> "" then
				' old format
				liveDataFeed = bsp.liveDataFeeds.Lookup(userVariable.url$)
				if type(liveDataFeed) <> "roAssociativeArray" then
					url = newTextParameterValue(userVariable.url$)
					liveDataFeed = newLiveDataFeedFromOldDataFormat(url, bsp.networkedVariablesUpdateInterval%)
					bsp.liveDataFeeds.AddReplace(liveDataFeed.name$, liveDataFeed)
				endif
				userVariable.liveDataFeed = liveDataFeed
			else if type(userVariable.liveDataFeedName$) <> "Invalid" and userVariable.liveDataFeedName$ <> "" then
				' new format
				userVariable.liveDataFeed = bsp.liveDataFeeds.Lookup(userVariable.liveDataFeedName$)
			endif
		next
	endif

' parse HTML sites

	htmlSitesContainer = BrightAuthor.meta.htmlSites

	if htmlSitesContainer.Count() = 1 then
	
		htmlSitesXML = htmlSitesContainer.GetChildElements()

		for each htmlSiteXML in htmlSitesXML
			htmlSite = newHTMLSite(bsp, htmlSiteXML)
			bsp.htmlSites.AddReplace(htmlSite.name$, htmlSite)
		next

	endif

' parse presentations

	presentationsContainer = BrightAuthor.meta.presentationIdentifiers

	if presentationsContainer.Count() = 1 then
	
		presentationsXML = presentationsContainer.GetChildElements()

		for each presentationXML in presentationsXML
			presentation = newPresentation(bsp, presentationXML)
			bsp.presentations.AddReplace(presentation.name$, presentation)
		next

	endif

' get list of additional files to publish

	additionalPublishedFilesXML = BrightAuthor.meta.additionalFileToPublish
	for each additionalPublishedFileXML in additionalPublishedFilesXML
		additionalPublishedFile = {}
		additionalPublishedFile.fileName$ = additionalPublishedFileXML.GetText()
	    additionalPublishedFile.filePath$ = GetPoolFilePath(bsp.syncPoolFiles, additionalPublishedFile.fileName$)
		bsp.additionalPublishedFiles.push(additionalPublishedFile)
	next

' parse BoseProducts.xml

    boseProductsXML = BrightAuthor.meta.boseProduct
	if boseProductsXML.Count() > 0 then
		Sign.boseProducts = CreateObject("roAssociativeArray")
		for each boseProductXML in boseProductsXML
			boseProduct = CreateObject("roAssociativeArray")
			boseProduct.productName$ = boseProductXML.productName.GetText()
			boseProduct.port$ = boseProductXML.port.GetText()
			Sign.boseProducts.AddReplace(boseProduct.productName$, boseProduct)
			
			boseProductSpec = bsp.GetBoseProductSpec(boseProduct.productName$)
			if type(boseProductSpec) = "roAssociativeArray" then
	            port% = int(val(boseProduct.port$))
	            serialPortConfiguration = Sign.serialPortConfigurations[port%]
				serialPortConfiguration.serialPortSpeed% = boseProductSpec.baudRate%
				serialPortConfiguration.serialPortMode$ = boseProductSpec.dataBits$ + boseProductSpec.parity$ + boseProductSpec.stopBits$
				serialPortConfiguration.sendEol$ = GetEolFromSpec(boseProductSpec.sendEol$)
				serialPortConfiguration.receiveEol$ = GetEolFromSpec(boseProductSpec.receiveEol$)
				serialPortConfiguration.invertSignals = boseProductSpec.invertSignals
			endif
		next
	endif

    Sign.tripleUSBPort$ = BrightAuthor.meta.tripleUSBPort.GetText()
    if BrightAuthor.meta.tripleUSBPort.Count() = 1 then
		port% = int(val(BrightAuthor.meta.tripleUSBPort.GetText()))
        serialPortConfiguration = Sign.serialPortConfigurations[port%]
		serialPortConfiguration.serialPortSpeed% = 9600
		serialPortConfiguration.serialPortMode$ = "8N1"
    endif
        
    ' set default serial port speed, mode
    bsp.serialPortConfigurations = CreateObject("roArray", 6, true)
    for i% = 0 to 5
        if type(Sign.serialPortConfigurations[i%]) = "roAssociativeArray" then
            serialPortConfiguration = CreateObject("roAssociativeArray")
            serialPortConfiguration.serialPortSpeed% = Sign.serialPortConfigurations[i%].serialPortSpeed%
            serialPortConfiguration.serialPortMode$ = Sign.serialPortConfigurations[i%].serialPortMode$
            serialPortConfiguration.protocol$ = Sign.serialPortConfigurations[i%].protocol$
            serialPortConfiguration.sendEol$ = Sign.serialPortConfigurations[i%].sendEol$
            serialPortConfiguration.receiveEol$ = Sign.serialPortConfigurations[i%].receiveEol$
            serialPortConfiguration.invertSignals = Sign.serialPortConfigurations[i%].invertSignals
            bsp.serialPortConfigurations[i%] = serialPortConfiguration
        endif
    next
    
    Sign.udpReceivePort = int(val(BrightAuthor.meta.udpReceiverPort.GetText()))
    Sign.udpSendPort = int(val(BrightAuthor.meta.udpDestinationPort.GetText()))
    Sign.udpAddressType$ = BrightAuthor.meta.udpDestinationAddressType.GetText()
    if Sign.udpAddressType$ = "" then Sign.udpAddressType$ = "IPAddress"
    Sign.udpAddress$ = BrightAuthor.meta.udpDestinationAddress.GetText()

    Sign.flipCoordinates = false
    flipCoordinates$ = BrightAuthor.meta.flipCoordinates.GetText()
    if flipCoordinates$ = "true" then Sign.flipCoordinates = true
    
    Sign.touchCursorDisplayMode$ = BrightAuthor.meta.touchCursorDisplayMode.GetText()
        
    audioInSampleRate$ = BrightAuthor.meta.audioInSampleRate.GetText()
    if audioInSampleRate$ <> "" then
		Sign.audioInSampleRate% = int(val(audioInSampleRate$))
    else
		Sign.audioInSampleRate% = 48000
    endif
    
    Sign.gpio0Config = BrightAuthor.meta.gpio0.GetText()
    if Sign.gpio0Config = "input" then
        controlPort.EnableInput(0)
    else
        controlPort.EnableOutput(0)
    endif
    
    Sign.gpio1Config = BrightAuthor.meta.gpio1.GetText()
    if Sign.gpio1Config = "input" then
        controlPort.EnableInput(1)
    else
        controlPort.EnableOutput(1)
    endif
    
    Sign.gpio2Config = BrightAuthor.meta.gpio2.GetText()
    if Sign.gpio2Config = "input" then
        controlPort.EnableInput(2)
    else
        controlPort.EnableOutput(2)
    endif
    
    Sign.gpio3Config = BrightAuthor.meta.gpio3.GetText()
    if Sign.gpio3Config = "input" then
        controlPort.EnableInput(3)
    else
        controlPort.EnableOutput(3)
    endif
    
    Sign.gpio4Config = BrightAuthor.meta.gpio4.GetText()
    if Sign.gpio4Config = "input" then
        controlPort.EnableInput(4)
    else
        controlPort.EnableOutput(4)
    endif
    
    Sign.gpio5Config = BrightAuthor.meta.gpio5.GetText()
    if Sign.gpio5Config = "input" then
        controlPort.EnableInput(5)
    else
        controlPort.EnableOutput(5)
    endif
    
    Sign.gpio6Config = BrightAuthor.meta.gpio6.GetText()
    if Sign.gpio6Config = "input" then
        controlPort.EnableInput(6)
    else
        controlPort.EnableOutput(6)
    endif
    
    Sign.gpio7Config = BrightAuthor.meta.gpio7.GetText()
    if Sign.gpio7Config = "input" then
        controlPort.EnableInput(7)
    else
        controlPort.EnableOutput(7)
    endif
    
    audio1MinVolume$ = BrightAuthor.meta.audio1MinVolume.GetText()
    if audio1MinVolume$ <> "" then
		Sign.audio1MinVolume% = int(val(audio1MinVolume$))
	else
		Sign.audio1MinVolume% = 0
	endif
	    
    audio1MaxVolume$ = BrightAuthor.meta.audio1MaxVolume.GetText()
    if audio1MaxVolume$ <> "" then
		Sign.audio1MaxVolume% = int(val(audio1MaxVolume$))
	else
		Sign.audio1MaxVolume% = 100
	endif
	    
    audio2MinVolume$ = BrightAuthor.meta.audio2MinVolume.GetText()
    if audio2MinVolume$ <> "" then
		Sign.audio2MinVolume% = int(val(audio2MinVolume$))
	else
		Sign.audio2MinVolume% = 0
	endif
	    
    audio2MaxVolume$ = BrightAuthor.meta.audio2MaxVolume.GetText()
    if audio2MaxVolume$ <> "" then
		Sign.audio2MaxVolume% = int(val(audio2MaxVolume$))
	else
		Sign.audio2MaxVolume% = 100
	endif
	    
    audio3MinVolume$ = BrightAuthor.meta.audio3MinVolume.GetText()
    if audio3MinVolume$ <> "" then
		Sign.audio3MinVolume% = int(val(audio3MinVolume$))
	else
		Sign.audio3MinVolume% = 0
	endif
	    
    audio3MaxVolume$ = BrightAuthor.meta.audio3MaxVolume.GetText()
    if audio3MaxVolume$ <> "" then
		Sign.audio3MaxVolume% = int(val(audio3MaxVolume$))
	else
		Sign.audio3MaxVolume% = 100
	endif
	    
    usbMinVolume$ = BrightAuthor.meta.usbMinVolume.GetText()
    if usbMinVolume$ <> "" then
		Sign.usbMinVolume% = int(val(usbMinVolume$))
	else
		Sign.usbMinVolume% = 0
	endif
	    
    usbMaxVolume$ = BrightAuthor.meta.usbMaxVolume.GetText()
    if usbMaxVolume$ <> "" then
		Sign.usbMaxVolume% = int(val(usbMaxVolume$))
	else
		Sign.usbMaxVolume% = 100
	endif
	    
    hdmiMinVolume$ = BrightAuthor.meta.hdmiMinVolume.GetText()
    if hdmiMinVolume$ <> "" then
		Sign.hdmiMinVolume% = int(val(hdmiMinVolume$))
	else
		Sign.hdmiMinVolume% = 0
	endif
	    
    hdmiMaxVolume$ = BrightAuthor.meta.hdmiMaxVolume.GetText()
    if hdmiMaxVolume$ <> "" then
		Sign.hdmiMaxVolume% = int(val(hdmiMaxVolume$))
	else
		Sign.hdmiMaxVolume% = 100
	endif
	
	inactivityTimeout$ = lcase(BrightAuthor.meta.inactivityTimeout.GetText())
	if inactivityTimeout$ = "true" then
		bsp.inactivityTimeout = true
	else
		bsp.inactivityTimeout = false
	endif

	inactivityTime$ = BrightAuthor.meta.inactivityTime.GetText()
	if len(inactivityTime$) > 0 then
		bsp.inactivityTime% = int(val(inactivityTime$))
	else
		bsp.inactivityTime% = 0
	endif

    ' get zones

    zoneList = BrightAuthor.zones.zone
    if type(zoneList) <> "roXMLList" then print "Invalid XML file - zone list not found" : stop
    numZones% = zoneList.Count()

    Sign.zonesHSM = CreateObject("roArray", numZones%, true)
    Sign.videoZoneHSM = invalid
    
    for each zone in zoneList

        bsZoneHSM = newZoneHSM(bsp, msgPort, Sign, zone, globalVariables)
        Sign.zonesHSM.push(bsZoneHSM)

        if (bsZoneHSM.type$ = "VideoOrImages" or bsZoneHSM.type$ = "VideoOnly") or Sign.videoZoneHSM = invalid then 
            Sign.videoZoneHSM = bsZoneHSM
        endif
                    
    next
         
    ' audioOutput, audioMode and audioMapping were set incorrectly on earlier versions of presentations
'    if version% < 4 then
'        for each bsZone in Sign.zones
'            if bsZone.type$ = "VideoOrImages" or bsZone.type$ = "VideoOnly" then
'                bsZone.audioOutput% = 4
'                bsZone.audioMode% = 0
'                bsZone.audioMapping% = 0
'            endif
'        next
'    endif
    
    return Sign
    
End Function

'endregion

'region User Variable DB
Sub ResetUserVariable()

	m.currentValue$ = m.defaultValue$

	m.bsp.UpdateDBVariable(m.name$, m.currentValue$)

End Sub


Sub SetCurrentUserVariableValue(value$ As String, postMsg As Boolean)

	m.currentValue$ = value$

	m.bsp.UpdateDBVariable(m.name$, m.currentValue$)

	if postMsg then
		userVariableChanged = CreateObject("roAssociativeArray")
		userVariableChanged["EventType"] = "USER_VARIABLE_CHANGE"
		userVariableChanged["UserVariable"] = m
		m.bsp.msgPort.PostMessage(userVariableChanged)
	endif

End Sub


Function GetCurrentUserVariableValue() As Object

	return m.currentValue$

End Function


Sub IncrementUserVariable()

	currentValue% = int(val(m.currentValue$))
	currentValue% = currentValue% + 1
	m.currentValue$ = StripLeadingSpaces(stri(currentValue%))

	m.bsp.UpdateDBVariable(m.name$, m.currentValue$)

End Sub


Function newUserVariable(bsp As Object, name$ As String, currentValue$ As String, defaultValue$ As String) As Object

	userVariable = CreateObject("roAssociativeArray")
	userVariable.GetCurrentValue = GetCurrentUserVariableValue
	userVariable.SetCurrentValue = SetCurrentUserVariableValue
	userVariable.Increment = IncrementUserVariable
	userVariable.Reset = ResetUserVariable
	 
	userVariable.bsp = bsp
	userVariable.name$ = name$
	userVariable.currentValue$ = currentValue$
	userVariable.defaultValue$ = defaultValue$
	userVariable.liveDataFeed = invalid

	return userVariable

End Function


Sub UpdateDBVariable(name$, currentValue$)

    params = { cv_param: currentValue$, vn_param: name$, sri_param:  m.currentDBSectionId% }

    m.userVariablesDB.RunBackground("UPDATE Variables SET CurrentValue=:cv_param WHERE VariableName=:vn_param AND SectionReferenceId=:sri_param;", params)

End Sub


Sub AddDBVariable(name$ As String, defaultValue$ As String)
	
	SQLITE_COMPLETE = 100

	insertStatement = m.userVariablesDB.CreateStatement("INSERT INTO Variables (SectionReferenceId, VariableName, CurrentValue, DefaultValue) VALUES(?,?,?,?);")

	if type(insertStatement) <> "roSqliteStatement" then
        m.diagnostics.PrintDebug("CreateStatement failure - " + insertStatement)
		stop
	endif

	params = CreateObject("roArray", 4, false)
	params[ 0 ] = m.currentDBSectionId%
	params[ 1 ] = name$
	params[ 2 ] = defaultValue$
	params[ 3 ] = defaultValue$

	bindResult = insertStatement.BindByOffset(params)

	if not bindResult then
        m.diagnostics.PrintDebug("BindByOffset failure")
		stop
	endif

	sqlResult = insertStatement.Run()

	if sqlResult <> SQLITE_COMPLETE
        m.diagnostics.PrintDebug("sqlResult <> SQLITE_COMPLETE")
	endif

	insertStatement.Finalise()

End Sub


Sub AddDBSection(sectionName$ As String)

	SQLITE_COMPLETE = 100

	insertStatement = m.userVariablesDB.CreateStatement("INSERT INTO Sections (SectionName) VALUES(:name_param);")

	if type(insertStatement) <> "roSqliteStatement" then
        m.diagnostics.PrintDebug("CreateStatement failure - " + insertStatement)
		stop
	endif

	params = { name_param: sectionName$ }

	bindResult = insertStatement.BindByName(params)

	if not bindResult then
        m.diagnostics.PrintDebug("BindByOffset failure")
		stop
	endif

	sqlResult = insertStatement.Run()

	if sqlResult <> SQLITE_COMPLETE
        m.diagnostics.PrintDebug("sqlResult <> SQLITE_COMPLETE")
	endif

	insertStatement.Finalise()

End Sub


Sub SetDBVersion(version$ As String)

	SQLITE_COMPLETE = 100

	insertStatement = m.userVariablesDB.CreateStatement("INSERT INTO SchemaVersion (Version) VALUES(:version_param);")

	if type(insertStatement) <> "roSqliteStatement" then
        m.diagnostics.PrintDebug("CreateStatement failure - " + insertStatement)
		stop
	endif

	params = { version_param: version$ }

	bindResult = insertStatement.BindByName(params)

	if not bindResult then
        m.diagnostics.PrintDebug("BindByOffset failure")
		stop
	endif

	sqlResult = insertStatement.Run()

	if sqlResult <> SQLITE_COMPLETE
        m.diagnostics.PrintDebug("sqlResult <> SQLITE_COMPLETE")
	endif

	insertStatement.Finalise()

End Sub


Sub CreateDBTable(statement$ As String)

	SQLITE_COMPLETE = 100

	createStmt = m.userVariablesDB.CreateStatement(statement$)

	if type(createStmt) <> "roSqliteStatement" then
        m.diagnostics.PrintDebug("CreateStatement failure - " + createStmt)
		stop
	endif

	sqlResult = createStmt.Run()

	if sqlResult <> SQLITE_COMPLETE
        m.diagnostics.PrintDebug("sqlResult <> SQLITE_COMPLETE")
	endif

	createStmt.Finalise()

End Sub


Function GetDBSectionId(sectionName$ As String) As Object

	SQLITE_ROWS = 102

	sectionId% = -1

	select$ = "SELECT SectionId FROM Sections WHERE SectionName = '" + sectionName$ + "';"

	selectStmt = m.userVariablesDB.CreateStatement(select$)

	if type(selectStmt) <> "roSqliteStatement" then
        m.diagnostics.PrintDebug("CreateStatement failure - " + selectStmt)
		stop
	endif

	sqlResult = selectStmt.Run()

	while sqlResult = SQLITE_ROWS

		resultsData = selectStmt.GetData()
	
		sectionId% = resultsData["SectionId"]

		sqlResult = selectStmt.Run() 
		   
	end while

	selectStmt.Finalise()

	return sectionId%

End Function


Sub ReadVariablesDB()

	SQLITE_ROWS = 102

	m.variablesDBExists = true

	m.dbSchemaVersion$ = "1.0"

	if type(m.userVariablesDB) <> "roSqliteDatabase" then

		m.userVariablesDB = CreateObject("roSqliteDatabase")
		m.userVariablesDB.SetPort(m.msgPort)

        m.diagnostics.PrintDebug("Open userVariables.db")

		ok = m.userVariablesDB.Open("userVariables.db")

		if not ok then
	
			ok = m.userVariablesDB.Create("userVariables.db")
			if not ok then stop

			m.CreateDBTable("CREATE TABLE SchemaVersion (Version TEXT);")
			m.SetDBVersion(m.dbSchemaVersion$)

			m.CreateDBTable("CREATE TABLE Sections (SectionId INTEGER PRIMARY KEY AUTOINCREMENT, SectionName TEXT);")

			m.CreateDBTable("CREATE TABLE Variables (VariableId INTEGER PRIMARY KEY AUTOINCREMENT, SectionReferenceId INT, VariableName text, CurrentValue TEXT, DefaultValue TEXT);")

		endif

	endif

	if type(m.userVariableSets) <> "roAssociativeArray" then
		m.userVariableSets = CreateObject("roAssociativeArray")
	endif

	' get sections, variables
	selectStmt = m.userVariablesDB.CreateStatement("SELECT Sections.SectionName, Variables.VariableName, Variables.CurrentValue, Variables.DefaultValue FROM Variables INNER JOIN Sections ON Sections.SectionId = Variables.SectionReferenceId ORDER BY Sections.SectionName;")

	if type(selectStmt) <> "roSqliteStatement" then
        m.diagnostics.PrintDebug("CreateStatement failure - " + selectStmt)
		stop
	endif

	sqlResult = selectStmt.Run()

	while sqlResult = SQLITE_ROWS

		resultsData = selectStmt.GetData()
	
		sectionName$ = resultsData["SectionName"]
		if m.userVariableSets.DoesExist(sectionName$) then
			userVariables = m.userVariableSets.Lookup(sectionName$)
		else
			userVariables = CreateObject("roAssociativeArray")
			m.userVariableSets.AddReplace(sectionName$, userVariables)
		endif

		variableName$ = resultsData["VariableName"]
		currentValue$ = resultsData["CurrentValue"]
		defaultValue$ = resultsData["DefaultValue"]

		userVariable = newUserVariable(m, variableName$, currentValue$, defaultValue$)
		userVariables.AddReplace(variableName$, userVariable)

		sqlResult = selectStmt.Run() 
		   
	end while

	selectStmt.Finalise()

End Sub


Sub ExportVariablesDBToAsciiFile(file As Object)

	file.SendLine("Version" + chr(9) + m.dbSchemaVersion$)

	if type(m.userVariableSets) = "roAssociativeArray" then

		for each presentationName in m.userVariableSets

			file.SendLine("Section" + chr(9) + presentationName)

			userVariables = m.userVariableSets.Lookup(presentationName)

			for each variableName in userVariables
				userVariable = userVariables.Lookup(variableName)
				if type(userVariable) = "roAssociativeArray" then
					file.SendLine(userVariable.name$ + chr(9) + userVariable.currentValue$ + chr(9) + userVariable.defaultValue$)
				endif
			next

		next

	endif

End Sub


Function GetUserVariable(variableName$ As String) As Object

	userVariable = invalid

	if type(m.userVariableSets) = "roAssociativeArray" then
		if m.userVariableSets.DoesExist(m.activePresentation$) then
			userVariables = m.userVariableSets.Lookup(m.activePresentation$)
			if userVariables.DoesExist(variableName$) then
				userVariable = userVariables.Lookup(variableName$)
			endif
		endif
	endif

	return userVariable

End Function


Sub ResetVariables()

	if type(m.userVariableSets) = "roAssociativeArray" then
		if m.userVariableSets.DoesExist(m.activePresentation$) then
			userVariables = m.userVariableSets.Lookup(m.activePresentation$)

			userVariableList = CreateObject("roList")
			for each variableName in userVariables
				userVariable = userVariables.Lookup(variableName)
				userVariableList.AddTail(userVariable)
			next

			for each userVariable in userVariableList
				userVariable.Reset()
			next

		endif
	endif

End Sub

'endregion

'region newSign helpers
Function GetBPConfiguration(bpHardware$ As String, bp900ConfigureAutomatically As Boolean, bp900Configuration% As Integer, bp200ConfigureAutomatically As Boolean, bp200Configuration% As Integer) As Integer
	
	if bpHardware$ = "BP900" then
		if bp900ConfigureAutomatically then
			return 0
		else
			return bp900Configuration%
		endif
	else
		if bp200ConfigureAutomatically then
			return 0
		else
			return bp200Configuration%
		endif
	endif

End Function


Function GetBoolFromString(str$ As String, defaultValue As Boolean) As Boolean

	if str$ = "" then
		return defaultValue
	else if lcase(str$) = "true" then
		return true
	else
		return false
	endif

End Function


Function GetIntFromString(str$ As String) As Integer

	if str$ <> "" then
		return int(val(str$))
	else
		return 0
	endif

End Function

'endregion

'region ZoneHSM
Function newZoneHSM(bsp As Object, msgPort As Object, sign As Object, zoneXML As Object, globalVariables As Object) As Object

    zoneType$ = zoneXML.type.GetText()

    ' create objects and read zone specific parameters
    
    if zoneType$ = "VideoOrImages" then
    
        zoneHSM = newVideoOrImagesZoneHSM(bsp, zoneXML)
        
    else if zoneType$ = "VideoOnly" then
    
        zoneHSM = newVideoZoneHSM(bsp, zoneXML)
        
    else if zoneType$ = "Images" then
    
        zoneHSM = newImagesZoneHSM(bsp, zoneXML)
        
    else if zoneType$ = "AudioOnly" then
    
		zoneHSM = newAudioZoneHSM(bsp, zoneXML)
		
    else if zoneType$ = "EnhancedAudio" then

		zoneHSM = newEnhancedAudioZoneHSM(bsp, zoneXML)

	else if zoneType$ = "Ticker" then
    
        zoneHSM = newTickerZoneHSM(bsp, sign, zoneXML)
        
    else if zoneType$ = "Clock" then
    
        zoneHSM = newClockZoneHSM(bsp, zoneXML)
    
    else if zoneType$ = "BackgroundImage" then
    
        zoneHSM = newBackgroundImageZoneHSM(bsp, zoneXML)
            
    endif

	zoneHSM.CreateObjects = CreateObjects
	zoneHSM.CreateObjectsNeededForTransitionCommands = CreateObjectsNeededForTransitionCommands
	zoneHSM.CreateObjectForTransitionCommand = CreateObjectForTransitionCommand
    zoneHSM.CreateSerial = CreateSerial
    zoneHSM.CreateUDPSender = CreateUDPSender    

	zoneHSM.StopSignChannelInZone = StopSignChannelInZone
	
    zoneHSM.InitializeZoneCommon = InitializeZoneCommon

	zoneHSM.LoadImageBuffers = LoadImageBuffers
	zoneHSM.AddImageBufferItem = AddImageBufferItem
		        
    zoneHSM.language$ = globalVariables.language$
    
    ' create and read playlist
    playlistXML = zoneXML.playlist
    numPlaylists% = playlistXML.Count()
        
    if numPlaylists% = 1 then
        zoneHSM.playlist = newPlaylist(bsp, zoneHSM, sign, playlistXML)
    endif

    zoneHSM.playbackActive = false

    return zoneHSM
    
End Function


Function newPlaylist(bsp As Object, zoneHSM As Object, sign As Object, playlistXML As Object) As Object

    playlistBS = CreateObject("roAssociativeArray")
    
    playlistBS.name$ = playlistXML.name.GetText()

' get states
    
    stateList = playlistXML.states.state
    if type(stateList) <> "roXMLList" then print "Invalid XML file - state list not found" : stop
    
    initialStateXML = playlistXML.states.initialState
    if type(initialStateXML) <> "roXMLList" then print "Invalid XML file - initial state not found" : stop

    initialStateName$ = initialStateXML.GetText()

	if zoneHSM.type$ = "Ticker" then
	
		zoneHSM.rssDataFeedItems = CreateObject("roArray", 2, true)

		for each state in stateList
		
			tickerItem = newTickerItem(bsp, zoneHSM, state)
			
			zoneHSM.rssDataFeedItems.push(tickerItem)

		next
		
	else
	
		zoneHSM.stateTable = CreateObject("roAssociativeArray")
	    
		for each state in stateList
	    
			bsState = newState(bsp, zoneHSM, sign, state)

			if bsState.id$ = initialStateName$ then
				playlistBS.firstState = bsState
				playlistBS.firstStateName$ = initialStateName$
			endif

			zoneHSM.stateTable[bsState.id$] = bsState

		next

	' match up superstates

		for each stateName in zoneHSM.stateTable
			bsState = zoneHSM.stateTable[stateName]
			superStateName$ = bsState.superStateName$
			if superStateName$ <> "" and superStateName$ <> "top" then
				bsState.superState = zoneHSM.stateTable[superStateName$]
			endif
		next
	        
	' get transitions

		transitionList = playlistXML.states.transition

		for each transition in transitionList
	    
			newTransition(bsp, zoneHSM, sign, transition)
	        
		next
	     
    endif
                  
    return playlistBS
        
End Function


Function ConvertToByteArray(input$ As String) As Object

	inputSpec = CreateObject("roByteArray")
	
	' convert serial$ into byte array
    byteString$ = StripLeadingSpaces(input$)
    commaPosition = -1
    while commaPosition <> 0	
        commaPosition = instr(1, byteString$, ",")
        if commaPosition = 0 then
			byteValue = val(byteString$)
        else 
            byteValue = val(left(byteString$, commaPosition - 1))
        endif
        inputSpec.push(byteValue)
	    byteString$ = mid(byteString$, commaPosition+1)
    end while
            
	return inputSpec
	            
End Function


Sub newTransition(bsp As Object, zoneHSM As Object, sign As Object, transitionXML As Object)

    stateTable = zoneHSM.stateTable
    
    sourceMediaState$ = transitionXML.sourceMediaState.GetText()

' given the sourceMediaState, find the associated bsState
	bsState = stateTable.Lookup(sourceMediaState$)
    if type(bsState) <> "roAssociativeArray" then print "Media state specified in transition not found" : stop

    userEvent = transitionXML.userEvent
    if userEvent.Count() <> 1 then print "Invalid XML file - userEvent not found" : stop
    userEventName$ = userEvent.name.GetText()

    nextMediaState$ = transitionXML.targetMediaState.GetText()
    
    transition = CreateObject("roAssociativeArray")
	transition.AssignEventInputToUserVariable = AssignEventInputToUserVariable

    transition.targetMediaState$ = nextMediaState$
    
    nextIsPrevious$ = transitionXML.targetIsPreviousState.GetText()
    transition.targetMediaStateIsPreviousState = false
    if nextIsPrevious$ <> "" and lcase(nextIsPrevious$) = "yes" then
        transition.targetMediaStateIsPreviousState = true
    endif

	transition.assignInputToUserVariable = false
	if lcase(transitionXML.assignInputToUserVariable.GetText()) = "true" then
		transition.assignInputToUserVariable = true
		transition.variableToAssign = invalid
		variableToAssign$ = transitionXML.variableToAssign.GetText()
		if variableToAssign$ <> "" then
			transition.variableToAssign = bsp.GetUserVariable(variableToAssign$)
			if transition.variableToAssign = invalid then
				bsp.diagnostics.PrintDebug("User variable " + variableToAssign$ + " not found.")
			endif
		endif
	endif

    if userEventName$ = "gpioUserEvent" then

        gpioInput$ = userEvent.parameters.parameter.GetText()
        gpioEvents = bsState.gpioEvents
        gpioEvents[gpioInput$] = transition

	else if userEventName$ = "bp900AUserEvent" or userEventName$ = "bp900BUserEvent" or userEventName$ = "bp900CUserEvent" or userEventName$ = "bp200AUserEvent" or userEventName$ = "bp200BUserEvent" or userEventName$ = "bp200CUserEvent" then

		transition.configuration$ = "press"

		buttonPanelIndex% = int(val(userEvent.parameters.buttonPanelIndex.GetText()))
		buttonNumber$ = userEvent.parameters.buttonNumber.GetText()
		
		continuousConfigs = userEvent.parameters.GetNamedElements("pressContinuous")
		if continuousConfigs.Count() = 1 then
			continuousConfig = continuousConfigs[0]
			transition.configuration$ = "pressContinuous"
			transition.initialHoldoff$ = continuousConfig.initialHoldoff.GetText()
			transition.repeatInterval$ = continuousConfig.repeatInterval.GetText()
		endif
		
		bsp.ConfigureBPInput(buttonPanelIndex%, buttonNumber$)
		
        bpEvents = bsState.bpEvents
        currentBPEvent = bpEvents[buttonPanelIndex%]
        currentBPEvent.AddReplace(buttonNumber$, transition)
	        
    else if userEventName$ = "gpsEvent" then

		enterRegion$ = userEvent.parameters.enterRegion.GetText()

		transition.radiusInFeet = val(userEvent.parameters.gpsRegion.radiusInFeet.GetText())
		transition.latitude = val(userEvent.parameters.gpsRegion.latitude.GetText())
		transition.latitudeInRadians = ConvertDecimalDegtoRad(transition.latitude)
		transition.longitude = val(userEvent.parameters.gpsRegion.longitude.GetText())
		transition.longitudeInRadians = ConvertDecimalDegtoRad(transition.longitude)

		if lcase(enterRegion$) = "true" then
			bsState.gpsEnterRegionEvents.push(transition)
		else
			bsState.gpsExitRegionEvents.push(transition)
		endif

	else if userEventName$ = "serial" then

        ' support both old style and new style serial events
        if userEvent.parameters.parameter2.Count() = 1 then
            port$ = userEvent.parameters.parameter.GetText()
            serial$ = userEvent.parameters.parameter2.GetText()
        else
            port$ = "0"
            serial$ = userEvent.parameters.parameter.GetText()
        endif
        
		port% = int(val(port$))
		serialPortConfiguration = sign.serialPortConfigurations[port%]
		protocol$ = serialPortConfiguration.protocol$

		serialEvents = bsState.serialEvents
		if type(serialEvents[port$]) <> "roAssociativeArray" then
			serialEvents[port$] = CreateObject("roAssociativeArray")
		endif

	    if protocol$ = "Binary" then
			if type(serialEvents[port$].streamInputTransitionSpecs) <> "roArray" then
				serialEvents[port$].streamInputTransitionSpecs = CreateObject("roArray", 1, true)
			endif
			
			streamInputTransitionSpec = CreateObject("roAssociativeArray")
			streamInputTransitionSpec.transition = transition
			streamInputTransitionSpec.inputSpec = ConvertToByteArray(serial$)
			streamInputTransitionSpec.asciiSpec = serial$
			serialEvents[port$].streamInputTransitionSpecs.push(streamInputTransitionSpec)

		else
			serialPortEvents = serialEvents[port$]
			serialPortEvents[serial$] = transition
        endif
		                            
    else if userEventName$ = "usbBinaryEtap" then

        usbBinaryEtap$ = userEvent.parameters.parameter.GetText()

		usbBinaryEtapInputTransitionSpec = CreateObject("roAssociativeArray")
		usbBinaryEtapInputTransitionSpec.transition = transition
		usbBinaryEtapInputTransitionSpec.inputSpec = ConvertToByteArray(usbBinaryEtap$)
		usbBinaryEtapInputTransitionSpec.asciiSpec = usbBinaryEtap$

        if type(bsState.usbBinaryEtapEvents) <> "roArray" then
            bsState.usbBinaryEtapEvents = CreateObject("roArray", 1, true)
        endif
        
		bsState.usbBinaryEtapEvents.push(usbBinaryEtapInputTransitionSpec)
		        
    else if userEventName$ = "timeout" then
    
        bsState.mstimeoutValue% = int(val(userEvent.parameters.parameter.GetText()) * 1000)        
        bsState.mstimeoutEvent = transition

    else if userEventName$ = "timeClockEvent" then

		timeClockEventTransitionSpec = { }
		timeClockEventTransitionSpec.transition = transition

		if type(userEvent.timeClockEvent.timeClockDateTime.GetChildElements()) = "roXMLList" then
			dateTime$ = userEvent.timeClockEvent.timeClockDateTime.dateTime.GetText()
			timeClockEventTransitionSpec.timeClockEventDateTime = FixDateTime(dateTime$)
		else if type(userEvent.timeClockEvent.timeClockDateTimeByUserVariable.GetChildElements()) = "roXMLList" then
			userVariableName$ = userEvent.timeClockEvent.timeClockDateTimeByUserVariable.userVariableName.GetText()
			timeClockEventTransitionSpec.userVariableName$ = userVariableName$
			timeClockEventTransitionSpec.userVariable = bsp.GetUserVariable(userVariableName$)
		else
			timeClockEventTransitionSpec.daysOfWeek% = int(val(userEvent.timeClockEvent.timeClockDailyOnce.daysOfWeek.GetText()))
			if type(userEvent.timeClockEvent.timeClockDailyOnce.GetChildElements()) = "roXMLList" then
				timeClockEventTransitionSpec.timeClockDaily% = int(val(userEvent.timeClockEvent.timeClockDailyOnce.eventTime.GetText()))
			else
				timeClockEventTransitionSpec.daysOfWeek% = int(val(userEvent.timeClockEvent.timeClockDailyPeriodic.daysOfWeek.GetText()))
				timeClockEventTransitionSpec.timeClockPeriodicInterval% = int(val(userEvent.timeClockEvent.timeClockDailyPeriodic.intervalTime.GetText()))
				timeClockEventTransitionSpec.timeClockPeriodicStartTime% = int(val(userEvent.timeClockEvent.timeClockDailyPeriodic.startTime.GetText()))
				timeClockEventTransitionSpec.timeClockPeriodicEndTime% = int(val(userEvent.timeClockEvent.timeClockDailyPeriodic.endTime.GetText()))
			endif
		endif

		if type(bsState.timeClockEvents) <> "roArray" then
			bsState.timeClockEvents = CreateObject("roArray", 1, true) 
		endif

		bsState.timeClockEvents.push(timeClockEventTransitionSpec)

	else if userEventName$ = "mediaEnd" then

		if bsState.type$ = "video" then
        
            bsState.videoEndEvent = transition

		else if bsState.type$ = "audio" then
        
            bsState.audioEndEvent = transition

		else if bsState.type$ = "signChannel" or bsState.type$ = "mediaRSS" then
        
            bsState.signChannelEndEvent = transition
        
        else if bsState.type$ = "mediaList" and bsState.mediaType$ = "video" then
        
			bsState.videoEndEvent = transition
			
        else if bsState.type$ = "mediaList" and bsState.mediaType$ = "audio" then
        
			bsState.audioEndEvent = transition
			
		else if bsState.type$ = "playFile" then

            bsState.videoEndEvent = transition
            bsState.audioEndEvent = transition

        else if bsState.type$ = "stream" then

			bsState.videoEndEvent = transition
			bsState.audioEndEvent = transition

		else if bsState.type$ = "mjpeg" then

			bsState.videoEndEvent = transition
		
		else if bsState.type$ = "rfInputChannel" then

			bsState.videoEndEvent = transition
		
		else if bsState.type$ = "rfScan" then

			bsState.videoEndEvent = transition
		
        endif
        
    else if userEventName$ = "keyboard" then

        keyboardChar$ = userEvent.parameters.parameter.GetText()
		if len(keyboardChar$) > 1 then
			keyboardChar$ = Lcase(keyboardChar$)
		endif

        if type(bsState.keyboardEvents) <> "roAssociativeArray" then
            bsState.keyboardEvents = CreateObject("roAssociativeArray")
        endif
        
        bsState.keyboardEvents[keyboardChar$] = transition
                
    else if userEventName$ = "remote" then

        remote$ = ucase(userEvent.parameters.parameter.GetText())

        if type(bsState.remoteEvents) <> "roAssociativeArray" then
            bsState.remoteEvents = CreateObject("roAssociativeArray")
        endif
        
        bsState.remoteEvents[remote$] = transition
        
    else if userEventName$ = "usb" then

        usbString$ = userEvent.parameters.parameter.GetText()
        
        if type(bsState.usbStringEvents) <> "roAssociativeArray" then
            bsState.usbStringEvents = CreateObject("roAssociativeArray")
        endif
        
        bsState.usbStringEvents[usbString$] = transition
        
    else if userEventName$ = "udp" then

        udp$ = userEvent.parameters.parameter.GetText()
        
        if type(bsState.udpEvents) <> "roAssociativeArray" then
            bsState.udpEvents = CreateObject("roAssociativeArray")
        endif
        
        bsState.udpEvents[udp$] = transition
    
    else if userEventName$ = "synchronize" then

        synchronize$ = userEvent.parameters.parameter.GetText()
        
        if type(bsState.synchronizeEvents) <> "roAssociativeArray" then
            bsState.synchronizeEvents = CreateObject("roAssociativeArray")
        endif
        
        bsState.synchronizeEvents[synchronize$] = transition
    
    else if userEventName$ = "zoneMessage" then
    
        zoneMessage$ = userEvent.parameters.parameter.GetText()
        
        if type(bsState.zoneMessageEvents) <> "roAssociativeArray" then
            bsState.zoneMessageEvents = CreateObject("roAssociativeArray")
        endif
        
        bsState.zoneMessageEvents[zoneMessage$] = transition
        
    else if userEventName$ = "internalSynchronize" then
    
        internalSynchronize$ = userEvent.parameters.parameter.GetText()
        
        if type(bsState.internalSynchronizeEvents) <> "roAssociativeArray" then
            bsState.internalSynchronizeEvents = CreateObject("roAssociativeArray")
        endif
        
        bsState.internalSynchronizeEvents[internalSynchronize$] = transition
        
    else if userEventName$ = "rectangularTouchEvent" then 
        
        if type(bsState.touchEvents) <> "roAssociativeArray" then
            bsState.touchEvents = CreateObject("roAssociativeArray")
        endif
        
        transition.x% = int(val(userEvent.parameters.x.GetText()))
        transition.y% = int(val(userEvent.parameters.y.GetText()))
        transition.width% = int(val(userEvent.parameters.width.GetText()))
        transition.height% = int(val(userEvent.parameters.height.GetText()))
        
        if sign.flipCoordinates then
            videoMode = CreateObject("roVideoMode")
            resX = videoMode.GetResX()
            resY = videoMode.GetResY()
            videoMode = invalid
            
            transition.x% = resX - (transition.x% + transition.width%)
            transition.y% = resY - (transition.y% + transition.height%)
        endif
    
        bsState.touchEvents[stri(sign.numTouchEvents%)] = transition
        sign.numTouchEvents% = sign.numTouchEvents% + 1

    else if userEventName$ = "videoTimeCodeEvent" then
    
        if type(bsState.videoTimeCodeEvents) <> "roAssociativeArray" then
            bsState.videoTimeCodeEvents = CreateObject("roAssociativeArray")
        endif
    
        transition.timeInMS% = int(val(userEvent.parameters.parameter.GetText()))
        bsState.videoTimeCodeEvents[stri(sign.numVideoTimeCodeEvents%)] = transition

        sign.numVideoTimeCodeEvents% = sign.numVideoTimeCodeEvents% + 1

    else if userEventName$ = "quietUserEvent" then
    
        bsState.quietUserEvent = transition
    
    else if userEventName$ = "loudUserEvent" then
    
		bsState.loudUserEvent = transition
		
    else if userEventName$ = "auxConnectUserEvent" then

        if type(bsState.auxConnectEvents) <> "roAssociativeArray" then
            bsState.auxConnectEvents = CreateObject("roAssociativeArray")
        endif

		audioConnector$ = userEvent.parameters.audioConnector.GetText()
		bsState.auxConnectEvents[audioConnector$] = transition

	else if userEventName$ = "auxDisconnectUserEvent" then

        if type(bsState.auxDisconnectEvents) <> "roAssociativeArray" then
            bsState.auxDisconnectEvents = CreateObject("roAssociativeArray")
        endif

		audioConnector$ = userEvent.parameters.audioConnector.GetText()
		bsState.auxDisconnectEvents[audioConnector$] = transition

	else if userEventName$ = "fail" then

		bsState.failEvent = transition
					
    endif
    
    ' get commands and conditional targets
    for each transitionItemXML in transitionXML.GetChildElements()

        if transitionItemXML.GetName() = "brightSignCmd" then

			if type(transition.transitionCmds) <> "roArray" then
				transition.transitionCmds = CreateObject("roArray", 1, true)
			endif

            newCmd(bsp, transitionItemXML, transition.transitionCmds)

        endif

		if transitionItemXML.GetName() = "conditionalTarget" then

			if type(transition.conditionalTargets) <> "roArray" then
				transition.conditionalTargets = CreateObject("roArray", 1, true)
			endif

            newConditionalTarget(bsp, transitionItemXML, transition.conditionalTargets)

		endif

    next

    for each transitionCmd in transition.transitionCmds
    
        ' if the transition command is for an internal synchronize, add an event that the master will receive after it sends the preload command
        if transitionCmd.name$ = "internalSynchronize" then
        
            if type(transition.internalSynchronizeEventsMaster) <> "roAssociativeArray" then
                transition.internalSynchronizeEventsMaster = CreateObject("roAssociativeArray")
            endif
            
            internalSynchronizeMasterTransition = CreateObject("roAssociativeArray")
            internalSynchronizeMasterTransition.targetMediaState$ = nextMediaState$
            internalSynchronizeMasterTransition.targetMediaStateIsPreviousState = false

			transition.internalSynchronizeEventsMaster[transitionCmd.parameters["synchronizeKeyword"].GetCurrentParameterValue()] = internalSynchronizeMasterTransition

            ' modify this state's transition to not go to the next media state
            transition.targetMediaState$ = ""
            
        endif
    
    next
        
End Sub


Function newConditionalTarget(bsp As Object, conditionalTargetXML As Object, conditionalTargets As Object)

	userVariableName$ = conditionalTargetXML.variableName.GetText()
	operator$ = conditionalTargetXML.operator.GetText()
	if operator$ = "" then operator$ = "EQ"
	userVariableValue$ = conditionalTargetXML.variableValue.GetText()
	userVariableValue2$ = conditionalTargetXML.variableValue2.GetText()
	targetMediaState$ = conditionalTargetXML.targetMediaState.GetText()
    nextIsPrevious$ = conditionalTargetXML.targetIsPreviousState.GetText()

	userVariable = bsp.GetUserVariable(userVariableName$)
	if type(userVariable) = "roAssociativeArray" then

		conditionalTarget = { }
		conditionalTarget.userVariable = userVariable
		conditionalTarget.operator$ = operator$
		conditionalTarget.userVariableValue$ = userVariableValue$
		conditionalTarget.userVariableValue2$ = userVariableValue2$
		conditionalTarget.targetMediaState$ = targetMediaState$
		conditionalTarget.targetMediaStateIsPreviousState = false
		if nextIsPrevious$ <> "" and lcase(nextIsPrevious$) = "yes" then
			conditionalTarget.targetMediaStateIsPreviousState = true
		endif

		brightSignCmdsXML = conditionalTargetXML.brightSignCmd
		if type(brightSignCmdsXML) = "roXMLList" and brightSignCmdsXML.Count() > 0 then
			conditionalTarget.transitionCmds = CreateObject("roArray", 1, true)
			for each brightSignCmdXML in brightSignCmdsXML
		        newCmd(bsp, brightSignCmdXML, conditionalTarget.transitionCmds)
			next
		endif

		conditionalTargets.push(conditionalTarget)

	else

        bsp.diagnostics.PrintDebug("User variable " + userVariableName$ + " not found.")
	
	endif

End Function


Function newTickerItem(bsp As Object, zoneHSM As Object, stateXML As Object)

	item = invalid
	
    if stateXML.rssItem.Count() = 1 then
        item = newRSSPlaylistItem(bsp, zoneHSM, stateXML.rssItem)
	else if stateXML.twitterItem.Count() = 1 then
		item = newTwitterPlaylistItem(bsp, zoneHSM, stateXML.twitterItem)
    else if stateXML.rssDataFeedPlaylistItem.Count() = 1 then
		item = newRSSDataFeedPlaylistItem(bsp, stateXML.rssDataFeedPlaylistItem)
	else if stateXML.textItem.Count() = 1 then
        item = newTextPlaylistItem(stateXML.textItem)
    endif           

    return item

End Function


Function newState(bsp As Object, zoneHSM As Object, sign As Object, stateXML As Object) As Object

' get the name
    stateName$ = stateXML.name.GetText()
    
    state = zoneHSM.newHState(bsp, stateName$)
	state.name$ = stateName$
	
' get the superstate    
    state.superStateName$ = stateXML.superState.GetText()
    if state.superStateName$ = "" or state.superStateName$ = "top" then
        state.superStateName$ = "top"
        state.superState = zoneHSM.stTop
    endif

' create data structures for arrays of specific events    
    state.gpioEvents = CreateObject("roAssociativeArray")
    
    state.bpEvents = CreateObject("roArray", 3, true)
    state.bpEvents[0] = CreateObject("roAssociativeArray")
    state.bpEvents[1] = CreateObject("roAssociativeArray")
    state.bpEvents[2] = CreateObject("roAssociativeArray")

    state.serialEvents = CreateObject("roAssociativeArray")
	state.gpsEnterRegionEvents = CreateObject("roArray", 1, true)
	state.gpsExitRegionEvents = CreateObject("roArray", 1, true)

' get the item

    item = CreateObject("roAssociativeArray")

    if stateXML.imageItem.Count() = 1 then
    
        newImagePlaylistItem(bsp, stateXML.imageItem, state, item)
        state.imageItem = item
        state.type$ = "image"
        zoneHSM.numImageItems% = zoneHSM.numImageItems% + 1
    
    else if stateXML.videoItem.Count() = 1 then
    
        newVideoPlaylistItem(bsp, stateXML.videoItem, state, item)
        state.videoItem = item
        state.type$ = "video"
    
    else if stateXML.liveVideoItem.Count() = 1 then
    
        newLiveVideoPlaylistItem(stateXML.liveVideoItem, state)
        state.type$ = "liveVideo"

	else if stateXML.rfInputItem.Count() = 1 then
	
		newRFInputPlaylistItem(bsp, stateXML.rfInputItem, state)
		state.type$ = "rfInputChannel"

	else if stateXML.rfScanItem.Count() = 1 then

		newRFScanPlaylistItem(stateXML.rfScanItem, state)
		state.type$ = "rfScan"

    else if stateXML.eventHandlerItem.Count() = 1 then
    
		newEventHandlerPlaylistItem(stateXML.eventHandlerItem, state)
		state.type$ = "eventHandler"
		
    else if stateXML.eventHandler2Item.Count() = 1 then
    
		newEventHandlerPlaylistItem(stateXML.eventHandler2Item, state)
		state.type$ = "eventHandler"
		
	else if stateXML.liveTextItem.Count() = 1 then
    
		newTemplatePlaylistItemFromLiveTextPlaylistItem(bsp, stateXML.liveTextItem, state)
		state.type$ = "template"

	else if stateXML.templatePlaylistItem.Count() = 1 then
	
		newTemplatePlaylistItem(bsp, stateXML.templatePlaylistItem, state)
		state.type$ = "template"
				
    else if stateXML.audioInItem.Count() = 1 then
    
		newAudioInPlaylistItem(bsp, stateXML.audioInItem, state)
		state.type$ = "audioIn"

		if zoneHSM.type$ = "VideoOrImages" or zoneHSM.type$ = "Images" then
	        zoneHSM.numImageItems% = zoneHSM.numImageItems% + 1
		endif
		
    else if stateXML.signChannelItem.Count() = 1 then
    
		' require that the storage is writable
		if bsp.sysInfo.storageIsWriteProtected then DisplayStorageDeviceLockedMessage()

        newSignChannelPlaylistItem(stateXML.signChannelItem, state)
        state.type$ = "signChannel"

		if zoneHSM.type$ = "VideoOrImages" or zoneHSM.type$ = "Images" then
	        zoneHSM.numImageItems% = zoneHSM.numImageItems% + 1
		endif
                    
    else if stateXML.rssImageItem.Count() = 1 then
    
		' require that the storage is writable
		if bsp.sysInfo.storageIsWriteProtected then DisplayStorageDeviceLockedMessage()

        newRSSImagePlaylistItem(bsp, stateXML.rssImageItem, state)
        state.type$ = "mediaRSS"

		if zoneHSM.type$ = "VideoOrImages" or zoneHSM.type$ = "Images" then
	        zoneHSM.numImageItems% = zoneHSM.numImageItems% + 1
		endif
	
	else if stateXML.localPlaylistItem.Count() = 1 then
	
		newLocalPlaylistItem(bsp, stateXML.localPlaylistItem, state)
		state.type$ = "mediaRSS"
		
		if zoneHSM.type$ = "VideoOrImages" or zoneHSM.type$ = "Images" then
	        zoneHSM.numImageItems% = zoneHSM.numImageItems% + 1
		endif
	                
    else if stateXML.audioItem.Count() = 1 then
    
        newAudioPlaylistItem(bsp, stateXML.audioItem, state, item)
        state.audioItem = item
        state.type$ = "audio"
    
	else if stateXML.mediaSuperState.Count() = 1 then
    
        state.HStateEventHandler = MediaItemEventHandler
		state.ExecuteTransition = ExecuteTransition
		state.GetNextStateName = GetNextStateName
        state.UpdatePreviousCurrentStateNames = UpdatePreviousCurrentStateNames
        
    else if stateXML.backgroundImageItem.Count() = 1 then
    
        newBackgroundImagePlaylistItem(bsp, stateXML.backgroundImageItem, state, item)
        state.backgroundImageItem = item
            
    else if stateXML.mediaListItem.Count() = 1 then
    
		newMediaListPlaylistItem(bsp, zoneHSM, stateXML.mediaListItem, state)
		state.type$ = "mediaList"
		
    else if stateXML.tripleUSBItem.Count() = 1 then

        newTripleUSBPlaylistItem(stateXML.tripleUSBItem, sign, state)
		state.type$ = "tripleUSB"
		
	else if stateXML.interactiveMenuItem.Count() = 1 then
	
		newInteractiveMenuPlaylistItem(bsp, sign, stateXML.interactiveMenuItem, state)
		state.type$ = "interactiveMenuItem"

		if zoneHSM.type$ = "VideoOrImages" or zoneHSM.type$ = "Images" then
	        zoneHSM.numImageItems% = zoneHSM.numImageItems% + 1
		endif
	
	else if stateXML.playFileItem.Count() = 1 then
		
		newPlayFilePlaylistItem(bsp, stateXML.playFileItem, state)
		state.type$ = "playFile"

		if stateXML.playFileItem.mediaType.GetText() = "image" then
			zoneHSM.numImageItems% = zoneHSM.numImageItems% + 1
		endif

    else if stateXML.streamItem.Count() = 1 then

        newStreamPlaylistItem(stateXML.streamItem, state)
		state.mediaType$ = "video"
        state.type$ = "stream"

    else if stateXML.videoStreamItem.Count() = 1 then

        newStreamPlaylistItem(stateXML.videoStreamItem, state)
		state.mediaType$ = "video"
        state.type$ = "stream"

    else if stateXML.audioStreamItem.Count() = 1 then

        newStreamPlaylistItem(stateXML.audioStreamItem, state)
		state.mediaType$ = "audio"
        state.type$ = "stream"

	else if stateXML.mjpegItem.Count() = 1 then

        newMjpegStreamPlaylistItem(stateXML.mjpegItem, state)
        state.type$ = "mjpeg"

	else if stateXML.html5Item.Count() = 1 then

		newHtml5PlaylistItem(bsp, stateXML.html5Item, state)
		state.type$ = "html5"

	endif           

' get any media state commands (commands that are executed when a state is entered)
    state.cmds = CreateObject("roArray", 1, true)

    ' new style commands    
    cmds = stateXML.brightSignCmd
    if stateXML.brightSignCmd.Count() > 0 then
        for each cmd in cmds
            newCmd(bsp, cmd, state.cmds)
        next
    endif

    return state
    
End Function


Function newTextParameterValue(value$ As String) As Object

	parameterValue = CreateObject("roAssociativeArray")
	parameterValue.GetCurrentParameterValue = GetCurrentParameterValue
	parameterValue.GetParameterValueSpec = GetParameterValueSpec

	parameterValue.parameterValueItems = CreateObject("roArray", 1, true)
	parameterValue.parameterValueItems.push(newParameterValueItemFromTextConstant(value$))

	return parameterValue

End Function


Function GetCurrentTextParameterValue() As String

	return m.textValue$

End Function


Function GetParameterValueSpecItemText() As String

	return m.textValue$

End Function


Function newParameterValueItemText(parameterValueItemTextXML As Object) As Object

	parameterValueItem = CreateObject("roAssociativeArray")
	parameterValueItem.GetCurrentValue = GetCurrentTextParameterValue
	parameterValueItem.GetParameterValueSpec = GetParameterValueSpecItemText

	parameterValueItem.type$ = "text"
	parameterValueItem.textValue$ = parameterValueItemTextXML.value.GetText()

	return parameterValueItem

End Function


Function newParameterValueItemFromTextConstant(textValue$ As String) As Object

	parameterValueItem = CreateObject("roAssociativeArray")
	parameterValueItem.GetCurrentValue = GetCurrentTextParameterValue
	parameterValueItem.GetParameterValueSpec = GetParameterValueSpecItemText

	parameterValueItem.type$ = "text"
	parameterValueItem.textValue$ = textValue$

	return parameterValueItem

End Function


Function GetCurrentUserVariableParameterValue() As String

	if type(m.userVariable) = "roAssociativeArray" then
		return m.userVariable.GetCurrentValue()
	else
		return ""
	endif

End Function


Function GetParameterValueSpecItemUserVariable() As String

	if type(m.userVariable) = "roAssociativeArray" then
		return "$$" + m.userVariable.name$ + "$$"
	else
		return ""
	endif

End Function


Function newParameterValueItemUserVariable(bsp As Object, parameterValueItemUserVariableXML As Object) As Object

	parameterValueItem = CreateObject("roAssociativeArray")
	parameterValueItem.GetCurrentValue = GetCurrentUserVariableParameterValue
	parameterValueItem.GetParameterValueSpec = GetParameterValueSpecItemUserVariable

	parameterValueItem.type$ = "userVariable"

	userVariableName$ = parameterValueItemUserVariableXML.userVariable.name.GetText()
	parameterValueItem.userVariable = bsp.GetUserVariable(userVariableName$)
	if type(parameterValueItem.userVariable) <> "roAssociativeArray" then
        bsp.diagnostics.PrintDebug("User variable " + userVariableName$ + " not found.")
	    bsp.logging.WriteDiagnosticLogEntry(bsp.diagnosticCodes.EVENT_USER_VARIABLE_NOT_FOUND, userVariableName$)
	endif

	return parameterValueItem

End Function


Function GetParameterValueSpecItemMediaCounterVariable() As String

	if type(m.userVariable) = "roAssociativeArray" then
		return "_" + m.userVariable.name$
	else
		return ""
	endif

End Function


Function newParameterValueItemMediaCounterVariable(bsp As Object, parameterValueItemMediaCounterVariable As Object) As Object

	parameterValueItem = CreateObject("roAssociativeArray")
	parameterValueItem.GetCurrentValue = GetCurrentUserVariableParameterValue
	parameterValueItem.GetParameterValueSpec = GetParameterValueSpecItemMediaCounterVariable

	parameterValueItem.type$ = "userVariable"

	variableName$ = parameterValueItemMediaCounterVariable.fileName.GetText()
	userVariableName$ = mid(variableName$, 2)
	parameterValueItem.userVariable = bsp.GetUserVariable(userVariableName$)
	if type(parameterValueItem.userVariable) <> "roAssociativeArray" then
        bsp.diagnostics.PrintDebug("Media counter variable " + userVariableName$ + " not found.")
	    bsp.logging.WriteDiagnosticLogEntry(bsp.diagnosticCodes.EVENT_MEDIA_COUNTER_VARIABLE_NOT_FOUND, userVariableName$)
	endif

	return parameterValueItem

End Function


Function GetCurrentParameterValue() As String

	value$ = ""

	for each parameterValueItem in m.parameterValueItems
		if type(parameterValueItem) = "roAssociativeArray" then
			value$ = value$ + parameterValueItem.GetCurrentValue()
		endif
	next

	return value$

End Function


Function GetVariableName() As String

	variableName$ = ""

	if m.parameterValueItems.Count() = 1 then
		parameterValueItem = m.parameterValueItems[0]
		if type(parameterValueItem) = "roAssociativeArray" then
			if parameterValueItem.type$ = "userVariable" then
				userVariable = parameterValueItem.userVariable
				variableName$ = userVariable.name$
			endif			
		endif
	endif

	return variableName$

End Function


Function GetParameterValueSpec() As String

	parameterValueSpec$ = ""

	for each parameterValueItem in m.parameterValueItems
		parameterValueSpec$ = parameterValueSpec$ + parameterValueItem.GetParameterValueSpec()
	next

	return parameterValueSpec$

End Function


Function newParameterValue(bsp As Object, parameterValueXML As Object) As Object

	parameterValue = CreateObject("roAssociativeArray")
	parameterValue.GetCurrentParameterValue = GetCurrentParameterValue
	parameterValue.GetVariableName = GetVariableName
	parameterValue.GetParameterValueSpec = GetParameterValueSpec

	parameterValue.parameterValueItems = CreateObject("roArray", 1, true)

	if type(parameterValueXML) = "roXMLList" and parameterValueXML.Count() = 1 then
		parameterValueItemsXML = parameterValueXML.GetChildElements()
		for each parameterValueItemXML in parameterValueItemsXML
			if parameterValueItemXML.GetName() = "parameterValueItemText" then
				parameterValue.parameterValueItems.push(newParameterValueItemText(parameterValueItemXML))
			else if parameterValueItemXML.GetName() = "parameterValueItemUserVariable" then
				parameterValue.parameterValueItems.push(newParameterValueItemUserVariable(bsp, parameterValueItemXML))
			else if parameterValueItemXML.GetName() = "parameterValueItemMediaCounterVariable" then
				parameterValue.parameterValueItems.push(newParameterValueItemMediaCounterVariable(bsp, parameterValueItemXML))
			endif
		next
	endif

	return parameterValue

End Function


Sub newCmd(bsp As Object, cmdXML As Object, cmds As Object)

    numCmds% = cmdXML.command.Count()
    if numCmds% > 0 then
        cmdsXML = cmdXML.command
        for each cmd in cmdsXML
            bsCmd = CreateObject("roAssociativeArray")
            bsCmd.name$ = cmd.name.GetText()
            bsCmd.parameters = CreateObject("roAssociativeArray")
            numParameters% = cmd.parameter.Count()

            if numParameters% > 0 then
                parameters = cmd.parameter
                for each parameter in parameters
					if type(parameter.value) = "roXMLList" and parameter.value.Count() = 1 then
						value$ = parameter.value.GetText()
						parameterValue = newTextParameterValue(value$)
					else
						parameterValue = newParameterValue(bsp, parameter.parameterValue)
					endif

					bsCmd.parameters.AddReplace(parameter.name.GetText(), parameterValue)
                next
            endif
            cmds.push(bsCmd)
            
            if bsCmd.name$ = "sendBPOutput" then
				buttonNumber$ = bsCmd.parameters.buttonNumber.GetCurrentParameterValue()
				buttonPanelIndex% = int(val(bsCmd.parameters.buttonPanelIndex.GetCurrentParameterValue()))
				action$ = bsCmd.parameters.action.GetCurrentParameterValue()
				if buttonNumber$ = "-1" then
					if action$ <> "off" then
						for i% = 0 to 10
							bsp.bpOutputUsed[buttonPanelIndex%, i%] = true
						next
					endif
				else
					buttonNumber% = int(val(buttonNumber$))
					bsp.bpOutputUsed[buttonPanelIndex%, buttonNumber%] = true
				endif
            else if bsCmd.name$ = "switchPresentation" then ' required for compatibility with old published presentations
				presentationName$ = bsCmd.parameters.presentationName.GetCurrentParameterValue()
				' new format has > 1 parameters: presentationName and useUserVariable
				if numParameters% = 1 then
					presentation = {}
					presentation.name$ = presentationName$
					presentation.presentationName$ = presentationName$
					presentation.path$ = presentationName$
					bsp.presentations.AddReplace(presentation.name$, presentation)
				endif
			endif
        next
    endif
        
End Sub


Sub UpdateWidgetVisibility(showImage As Boolean, hideImage As Boolean, clearImage As Boolean, showCanvas As Boolean, hideCanvas As Boolean, showHtml As Boolean, hideHtml As Boolean)

	if hideImage then
		if type(m.imagePlayer) = "roImageWidget" then
			m.imagePlayer.Hide()
		endif
	endif

	if clearImage then
		if type(m.imagePlayer) = "roImageWidget" then
			m.imagePlayer.StopDisplay()
		endif
	endif

	if hideCanvas then
		if type(m.canvasWidget) = "roCanvasWidget" then
			m.canvasWidget.Hide()
		endif
	endif

	if hideHtml then
		if type(m.displayedHtmlWidget) = "roHtmlWidget" then
			m.displayedHtmlWidget.Hide()
'			m.displayedHtmlWidget = invalid
		endif
	endif

	if showImage then
		if type(m.imagePlayer) = "roImageWidget" then
			m.imagePlayer.Show()
		endif
	endif

	if showCanvas then
		if type(m.canvasWidget) = "roCanvasWidget" then
			m.canvasWidget.Show()
		endif
	endif

	if showHtml then
		if type(m.displayedHtmlWidget) = "roHtmlWidget" then
			m.displayedHtmlWidget.Show()
		endif
	endif

End Sub


Sub ShowImageWidget()

	m.UpdateWidgetVisibility(true, false, false, false, true, false, true)

End Sub


Sub ClearImagePlane()

	m.UpdateWidgetVisibility(false, false, true, false, true, false, true)

End Sub


Sub ShowCanvasWidget()

	m.UpdateWidgetVisibility(false, true, false, true, false, false, true)

End Sub


Sub ShowHtmlWidget()

	m.UpdateWidgetVisibility(false, true, true, false, true, true, false)

End Sub


Sub LogPlayStart(itemType$ As String, fileName$ As String)

    if m.playbackActive then
        m.playbackEndTime$ = m.bsp.systemTime.GetLocalDateTime().GetString()
	    m.bsp.logging.WritePlaybackLogEntry(m.name$, m.playbackStartTime$, m.playbackEndTime$, m.playbackItemType$, m.playbackFileName$)
    endif
    
    m.playbackActive = true
    m.playbackStartTime$ = m.bsp.systemTime.GetLocalDateTime().GetString()
    m.playbackItemType$ = itemType$
    m.playbackFileName$ = fileName$
    
End Sub


Sub newMediaPlaylistItem(bsp As Object, playlistItemXML As Object, state As Object, playlistItemBS As Object)

    file = playlistItemXML.file
    fileAttrs = file.GetAttributes()
    playlistItemBS.fileName$ = fileAttrs["name"]
	playlistItemBS.userVariable = bsp.GetUserVariable(playlistItemBS.fileName$)

    state.MediaItemEventHandler = MediaItemEventHandler
	state.ExecuteTransition = ExecuteTransition
	state.GetNextStateName = GetNextStateName
    state.UpdatePreviousCurrentStateNames = UpdatePreviousCurrentStateNames
    state.LaunchTimer = LaunchTimer
    state.PreloadItem = PreloadItem

End Sub


Sub newImagePlaylistItem(bsp As Object, playlistItemXML As Object, state As Object, playlistItemBS As Object)

    newMediaPlaylistItem(bsp, playlistItemXML, state, playlistItemBS)
    playlistItemBS.slideDelayInterval% = int(val(playlistItemXML.slideDelayInterval.GetText()))
    playlistItemBS.slideTransition% = GetSlideTransitionValue(playlistItemXML.slideTransition.GetText())

	playlistItemBS.useImageBuffer = false
	useImageBuffer$ = playlistItemXML.useImageBuffer.GetText()
	if len(useImageBuffer$) > 0 then
		useImageBuffer$ = lcase(useImageBuffer$)
		if useImageBuffer$ = "true" then
			playlistItemBS.useImageBuffer = true
		endif
	endif

    state.HStateEventHandler = STDisplayingImageEventHandler
	state.DisplayImage = DisplayImage
    state.ConfigureBPButtons = ConfigureBPButtons

End Sub


Function GetProbeData(syncPoolFiles As Object, fileName$ As String) As Object

	probe = invalid

	poolFileInfo = syncPoolFiles.GetPoolFileInfo(fileName$)
	if type(poolFileInfo) = "roAssociativeArray" then
		probe = poolFileInfo.Lookup("probe")
	endif

	return probe

End Function


Sub newVideoPlaylistItem(bsp As Object, playlistItemXML As Object, state As Object, playlistItemBS As Object)

    newMediaPlaylistItem(bsp, playlistItemXML, state, playlistItemBS)

	playlistItemBS.probeData = GetProbeData(bsp.syncPoolFiles, playlistItemBS.fileName$)
    itemVolume$ = playlistItemXML.volume.GetText()
    if itemVolume$ <> "" then
        playlistItemBS.volume% = int(val(itemVolume$))
    endif
    
    playlistItemBS.videoDisplayMode% = 0
    videoDisplayMode$ = playlistItemXML.videoDisplayMode.GetText()
    if videoDisplayMode$ = "3DSBS" then
	    playlistItemBS.videoDisplayMode% = 1
	else if videoDisplayMode$ = "3DTOB" then
	    playlistItemBS.videoDisplayMode% = 2
    endif
    
    state.HStateEventHandler = STVideoPlayingEventHandler
    state.AddVideoTimeCodeEvent = AddVideoTimeCodeEvent
    state.SetVideoTimeCodeEvents = SetVideoTimeCodeEvents
    state.LaunchVideo = LaunchVideo
    state.ConfigureBPButtons = ConfigureBPButtons

End Sub


Sub newEventHandlerPlaylistItem(playlistItemXML As Object, state As Object)

	state.stopPlayback = false

	stopPlayback$ = playlistItemXML.stopPlayback.getText()
	if lcase(stopPlayback$) = "true" then
		state.stopPlayback = true
	endif

    state.HStateEventHandler = STEventHandlerEventHandler
    state.MediaItemEventHandler = MediaItemEventHandler
	state.ExecuteTransition = ExecuteTransition
	state.GetNextStateName = GetNextStateName
    state.UpdatePreviousCurrentStateNames = UpdatePreviousCurrentStateNames
    state.LaunchTimer = LaunchTimer
    state.ConfigureBPButtons = ConfigureBPButtons

End Sub


Sub newHtml5PlaylistItem(bsp As Object, playlistItemXML As Object, state As Object)

	state.name$ = playlistItemXML.name.GetText()
	state.htmlSiteName$ = playlistItemXML.htmlSiteName.GetText()

	' get the associated html site
	if bsp.htmlSites.DoesExist(state.htmlSiteName$) then
		htmlSite = bsp.htmlSites.Lookup(state.htmlSiteName$)
		state.contentIsLocal = htmlSite.contentIsLocal
		if state.contentIsLocal then
			state.prefix$ = htmlSite.prefix$
			state.filePath$ = htmlSite.filePath$
			state.url = invalid
		else
			state.url = htmlSite.url
		endif
	else
		' what to do here?
		stop
	endif

	state.enableExternalData = false
	if lcase(playlistItemXML.enableExternalData.GetText()) = "true" then
		state.enableExternalData = true
	endif

	state.enableMouseEvents = false
	if lcase(playlistItemXML.enableMouseEvents.GetText()) = "true" then
		state.enableMouseEvents = true
	endif

	state.displayCursor = false
	if lcase(playlistItemXML.displayCursor.GetText()) = "true" then
		state.displayCursor = true
	endif

	state.timeOnScreen% = int(val(playlistItemXML.timeOnScreen.GetText()))

    state.HStateEventHandler = STHTML5PlayingEventHandler
	state.MediaItemEventHandler = MediaItemEventHandler
    state.ConfigureBPButtons = ConfigureBPButtons
    state.LaunchTimer = LaunchTimer
	state.ExecuteTransition = ExecuteTransition
	state.GetNextStateName = GetNextStateName
    state.UpdatePreviousCurrentStateNames = UpdatePreviousCurrentStateNames

End Sub


Sub newRFScanPlaylistItem(playlistItemXML As Object, state As Object)

	state.scanSpec = { }

	channelMap$ = playlistItemXML.channelMap.GetText()
	state.scanSpec["ChannelMap"] = channelMap$

	modulationType$ = playlistItemXML.modulationType.GetText()

	if channelMap$ <> "ATSC" and modulationType$ <> "QAM64_QAM256" then
		state.scanSpec["ModulationType"] = modulationType$
	endif

	firstRFChannel$ = playlistItemXML.firstRFChannel.GetText()
	if firstRFChannel$ <> "" then
		state.scanSpec["FirstRfChannel"] = int(val(firstRFChannel$))
	endif

	lastRFChannel$ = playlistItemXML.lastRFChannel.GetText()
	if lastRFChannel$ <> "" then
		state.scanSpec["LastRfChannel"] = int(val(lastRFChannel$))
	endif

    state.HStateEventHandler = STRFScanHandler
	state.ProcessScannedChannels = ProcessScannedChannels
    state.MediaItemEventHandler = MediaItemEventHandler
	state.ExecuteTransition = ExecuteTransition
	state.GetNextStateName = GetNextStateName
    state.UpdatePreviousCurrentStateNames = UpdatePreviousCurrentStateNames
    state.LaunchTimer = LaunchTimer

End Sub


Sub newRFInputPlaylistItem(bsp As Object, playlistItemXML As Object, state As Object)

	state.channelDescriptor = { }

	state.firstScannedChannel = false
	virtualChannel$ = playlistItemXML.rfInChannelDescriptor.rfInputChannel.virtualChannel.getText()		' user specified channel name
	if virtualChannel$ <> "" then
		state.channelDescriptor.VirtualChannel = virtualChannel$
	else
		virtualChannel$ = playlistItemXML.rfInVirtualChannel.virtualChannel.getText()					' user specified virtual channel
		if virtualChannel$ <> "" then
			state.channelDescriptor.VirtualChannel = virtualChannel$
		else
			userVariable$ = playlistItemXML.rfInUserVariable.userVariable.getText()						' user specified user variable
			if userVariable$ <> "" then
				state.userVariable = bsp.GetUserVariable(userVariable$)
				state.channelDescriptor = invalid
			else
				state.channelDescriptor = bsp.scannedChannels[0]										' user specified first scanned channel
				state.firstScannedChannel = true
			endif
		endif
	endif

	state.reentryAction$ = playlistItemXML.reentryAction.GetText()

	if type(playlistItemXML.channelUp) = "roXMLList" and playlistItemXML.channelUp.Count() = 1 then
		state.channelUpEvent = CreateObject("roAssociativeArray")
		SetStateEvent(bsp, state.channelUpEvent, playlistItemXML.channelUp)
	endif

	if type(playlistItemXML.channelDown) = "roXMLList" and playlistItemXML.channelDown.Count() = 1 then
		state.channelDownEvent = CreateObject("roAssociativeArray")
		SetStateEvent(bsp, state.channelDownEvent, playlistItemXML.channelDown)
	endif

    itemVolume$ = playlistItemXML.volume.GetText()
    if itemVolume$ <> "" then
        state.volume% = int(val(itemVolume$))
    endif

    state.timeOnScreen% = int(val(playlistItemXML.timeOnScreen.GetText()))
    
	state.overscan = false
	if lcase(playlistItemXML.overscan.GetText()) = "true" then
		state.overscan = true
	endif

    state.HStateEventHandler = STRFInputPlayingHandler
	state.HandleIntraStateEvent = HandleIntraStateEvent
	state.ConfigureIntraStateEventHandlerButton = ConfigureIntraStateEventHandlerButton
    state.MediaItemEventHandler = MediaItemEventHandler
	state.ExecuteTransition = ExecuteTransition
	state.GetNextStateName = GetNextStateName
    state.UpdatePreviousCurrentStateNames = UpdatePreviousCurrentStateNames
    state.LaunchTimer = LaunchTimer

End Sub


Sub newLiveVideoPlaylistItem(playlistItemXML As Object, state As Object)

    itemVolume$ = playlistItemXML.volume.GetText()
    if itemVolume$ <> "" then
        state.volume% = int(val(itemVolume$))
    endif

    state.timeOnScreen% = int(val(playlistItemXML.timeOnScreen.GetText()))
    
	state.overscan = false
	if lcase(playlistItemXML.overscan.GetText()) = "true" then
		state.overscan = true
	endif

    state.HStateEventHandler = STLiveVideoPlayingEventHandler
    state.MediaItemEventHandler = MediaItemEventHandler
	state.ExecuteTransition = ExecuteTransition
	state.GetNextStateName = GetNextStateName
    state.UpdatePreviousCurrentStateNames = UpdatePreviousCurrentStateNames
    state.LaunchTimer = LaunchTimer

End Sub


Sub newInteractiveMenuPlaylistItem(bsp As Object, sign As Object, playlistItemXML As Object, state As Object)

	state.backgroundImage$ = ParseFileNameXML(playlistItemXML.backgroundImage)
	if state.backgroundImage$ <> "" then
		state.backgroundImageUseImageBuffer = ParseBoolAttribute(playlistItemXML.backgroundImage[0], "useImageBuffer")
	endif
	state.backgroundImageUserVariable = bsp.GetUserVariable(state.backgroundImage$)

	state.upNavigation = ParseNavigation(bsp, sign, playlistItemXML.upNavigationEvent)
	state.downNavigation = ParseNavigation(bsp, sign, playlistItemXML.downNavigationEvent)
	state.leftNavigation = ParseNavigation(bsp, sign, playlistItemXML.leftNavigationEvent)
	state.rightNavigation = ParseNavigation(bsp, sign, playlistItemXML.rightNavigationEvent)
	state.enterNavigation = ParseNavigation(bsp, sign, playlistItemXML.enterNavigationEvent)
	state.backNavigation = ParseNavigation(bsp, sign, playlistItemXML.backNavigationEvent)
	state.nextClipNavigation = ParseNavigation(bsp, sign, playlistItemXML.nextClipNavigationEvent)
	state.previousClipNavigation = ParseNavigation(bsp, sign, playlistItemXML.previousClipNavigationEvent)
    
    interactiveMenuItemsXML = playlistItemXML.interactiveMenuItems.interactiveMenuItem

	state.interactiveMenuItems = CreateObject("roArray", 2, true)

	for each interactiveMenuItemXML in interactiveMenuItemsXML
		interactiveMenuItem = newInteractiveMenuItem(bsp, interactiveMenuItemXML)
		state.interactiveMenuItems.push(interactiveMenuItem)	
	next
	
    state.HStateEventHandler = STInteractiveMenuEventHandler
    state.DrawInteractiveMenu = DrawInteractiveMenu
    state.DisplayNavigationOverlay = DisplayNavigationOverlay
    state.NavigateToMenuItem = NavigateToMenuItem
    state.RestartInteractiveMenuInactivityTimer = RestartInteractiveMenuInactivityTimer
    state.ExecuteInteractiveMenuEnter = ExecuteInteractiveMenuEnter
    state.LaunchInteractiveMenuVideoClip = LaunchInteractiveMenuVideoClip
    state.LaunchInteractiveMenuAudioClip = LaunchInteractiveMenuAudioClip
    state.DisplayInteractiveMenuImage = DisplayInteractiveMenuImage
    state.NextPrevInteractiveMenuLaunchMedia = NextPrevInteractiveMenuLaunchMedia
	state.ConsumeSerialByteInput = ConsumeSerialByteInput
    state.MediaItemEventHandler = MediaItemEventHandler
	state.ExecuteTransition = ExecuteTransition
	state.GetNextStateName = GetNextStateName
    state.UpdatePreviousCurrentStateNames = UpdatePreviousCurrentStateNames
    state.LaunchTimer = LaunchTimer
    state.ConfigureBPButtons = ConfigureBPButtons
    state.IsPlayingClip = IsPlayingClip
    state.ClearPlayingClip = ClearPlayingClip
    state.PreloadItem = PreloadItem
	state.ConfigureNavigationButton = ConfigureNavigationButton
	
End Sub


Function newInteractiveMenuItem(bsp As Object, interactiveMenuItemXML As Object) As Object

	interactiveMenuItem = CreateObject("roAssociativeArray")

	interactiveMenuItem.index$ = interactiveMenuItemXML.index.GetText()
	
	interactiveMenuItem.x% = int(val(interactiveMenuItemXML.x.GetText()))
	interactiveMenuItem.y% = int(val(interactiveMenuItemXML.y.GetText()))
	
	interactiveMenuItem.selectedImage$ = ParseFileNameXML(interactiveMenuItemXML.selectedImage)
	interactiveMenuItem.selectedImageUseImageBuffer = ParseBoolAttribute(interactiveMenuItemXML.selectedImage[0], "useImageBuffer")	
		
	interactiveMenuItem.unselectedImage$ = ParseFileNameXML(interactiveMenuItemXML.unselectedImage)
	interactiveMenuItem.unselectedImageUseImageBuffer = ParseBoolAttribute(interactiveMenuItemXML.unselectedImage[0], "useImageBuffer")	

    interactiveMenuItem.targetType$ = interactiveMenuItemXML.targetType.GetText()
	if interactiveMenuItem.targetType$ = "mediaFile" then

		interactiveMenuItem.targetVideoFile$ = ParseFileNameXML(interactiveMenuItemXML.targetVideoFile)
		interactiveMenuitem.targetVideoFileUserVariable = bsp.GetUserVariable(interactiveMenuItem.targetVideoFile$)
		
		interactiveMenuItem.targetAudioFile$ = ParseFileNameXML(interactiveMenuItemXML.targetAudioFile)
		interactiveMenuitem.targetAudioFileUserVariable = bsp.GetUserVariable(interactiveMenuItem.targetAudioFile$)

		interactiveMenuItem.targetImageFile$ = ParseFileNameXML(interactiveMenuItemXML.targetImageFile)
		interactiveMenuitem.targetImageFileUserVariable = bsp.GetUserVariable(interactiveMenuItem.targetImageFile$)
		if interactiveMenuItem.targetImageFile$ <> "" then
			element = interactiveMenuItemXML.targetImageFile[0]
			imageFileAttributes = element.GetAttributes()
			timeout$ = imageFileAttributes.Lookup("timeout")
			interactiveMenuItem.targetImageFileTimeout% = int(val(timeout$))	
			interactiveMenuItem.targetImageFileUseImageBuffer = ParseBoolAttribute(interactiveMenuItemXML.targetImageFile[0], "useImageBuffer")	
		else if interactiveMenuItem.targetVideoFile$ <> "" then
			interactiveMenuItem.probeData = GetProbeData(bsp.syncPoolFiles, interactiveMenuItem.targetVideoFile$)
		else if interactiveMenuItem.targetAudioFile$ <> "" then
			interactiveMenuItem.probeData = GetProbeData(bsp.syncPoolFiles, interactiveMenuItem.targetAudioFile$)
		endif

	else if interactiveMenuItem.targetType$ = "mediaState" then
	    interactiveMenuItem.targetMediaState$ = interactiveMenuItemXML.targetMediaState.GetText()
	endif
		
    nextIsPrevious$ = interactiveMenuItemXML.targetIsPreviousState.GetText()
    interactiveMenuItem.targetIsPreviousState = false
    if nextIsPrevious$ <> "" and lcase(nextIsPrevious$) = "yes" then
        interactiveMenuItem.targetIsPreviousState = true
    endif

    interactiveMenuItem.enterCmds = CreateObject("roArray", 1, true)
    cmdsXML = interactiveMenuItemXML.enterBrightSignCmds.brightSignCmd
    if cmdsXML.Count() > 0 then
        for each cmdXML in cmdsXML
            newCmd(bsp, cmdXML, interactiveMenuItem.enterCmds)
        next
    endif

	for each cmd in interactiveMenuItem.enterCmds
		commandName$ = cmd.name$
        if commandName$ = "sendUDPCommand" or commandName$ = "synchronize" then
            bsp.CreateUDPSender(bsp)
        else if commandName$ = "sendSerialStringCommand" or commandName$ = "sendSerialBlockCommand" or commandName$ = "sendSerialByteCommand" or commandName$ = "sendSerialBytesCommand" then
			port$ = cmd.parameters["port"].GetCurrentParameterValue()
			bsp.CreateSerial(bsp, port$, true)
        endif
	next

	interactiveMenuItem.upNavigationIndex$ = interactiveMenuItemXML.upNavigationMenuItem.GetText()
	if IsString(interactiveMenuItem.upNavigationIndex$) and interactiveMenuItem.upNavigationIndex$ <> "" then
		interactiveMenuItem.upNavigationIndex% = int(val(interactiveMenuItem.upNavigationIndex$))	
	else
		interactiveMenuItem.upNavigationIndex% = -1	
	endif
	
	interactiveMenuItem.downNavigationIndex$ = interactiveMenuItemXML.downNavigationMenuItem.GetText()
	if IsString(interactiveMenuItem.downNavigationIndex$) and interactiveMenuItem.downNavigationIndex$ <> "" then
		interactiveMenuItem.downNavigationIndex% = int(val(interactiveMenuItem.downNavigationIndex$))	
	else
		interactiveMenuItem.downNavigationIndex% = -1	
	endif

	interactiveMenuItem.leftNavigationIndex$ = interactiveMenuItemXML.leftNavigationMenuItem.GetText()
	if IsString(interactiveMenuItem.leftNavigationIndex$) and interactiveMenuItem.leftNavigationIndex$ <> "" then
		interactiveMenuItem.leftNavigationIndex% = int(val(interactiveMenuItem.leftNavigationIndex$))	
	else
		interactiveMenuItem.leftNavigationIndex% = -1	
	endif

	interactiveMenuItem.rightNavigationIndex$ = interactiveMenuItemXML.rightNavigationMenuItem.GetText()
	if IsString(interactiveMenuItem.rightNavigationIndex$) and interactiveMenuItem.rightNavigationIndex$ <> "" then
		interactiveMenuItem.rightNavigationIndex% = int(val(interactiveMenuItem.rightNavigationIndex$))	
	else
		interactiveMenuItem.rightNavigationIndex% = -1	
	endif
	
	return interactiveMenuItem
	
End Function


Function ParseFileNameXML(fileNameXML As Object) As String

	if fileNameXML.Count() = 1 then
		fileElement = fileNameXML[0]
		fileAttributes = fileElement.GetAttributes()
		fileName$ = fileAttributes.Lookup("name")
	else
		fileName$ = ""
	endif

	return fileName$
	
End Function


Function ParseBoolAttribute(elementXML As Object, attr$ As String) As Boolean

	element = elementXML
	attributes = element.GetAttributes()
	val = attributes.Lookup(attr$)
	if IsString(val) and lcase(val) = "true" then
		return true
	endif
	
	return false
	
End Function


Function ParseNavigation(bsp As Object, sign As Object, navigationXML As Object) As Object

	navigation = invalid
	
	if navigationXML.Count() = 1 then
		navigationElement = navigationXML[0]
		userEventsList = navigationElement.userEvent
		if userEventsList.Count() > 0 then
			navigation = CreateObject("roAssociativeArray")
			for each userEvent in userEventsList
				ParseUserEvent(bsp, sign, navigation, userEvent)
			next
		endif
	endif

	return navigation
	
End Function


Sub ParseUserEvent(bsp As Object, sign As Object, aa As Object, userEvent As Object)

    userEventName$ = userEvent.name.GetText()

	if userEventName$ = "keyboard" then

		aa.keyboardChar$ = userEvent.parameters.parameter.GetText()
		if len(aa.keyboardChar$) > 1 then
			aa.keyboardChar$ = Lcase(aa.keyboardChar$)
		endif
        
    else if userEventName$ = "remote" then

        aa.remoteEvent$ = ucase(userEvent.parameters.parameter.GetText())

        if type(bsp.remote) <> "roIRRemote" then
            bsp.remote = CreateObject("roIRRemote")
            bsp.remote.SetPort(bsp.msgPort)
        endif
		        
	else if userEventName$ = "serial" then
	
        port$ = userEvent.parameters.parameter.GetText()
        serial$ = userEvent.parameters.parameter2.GetText()

		port% = int(val(port$))
		serialPortConfiguration = sign.serialPortConfigurations[port%]
		protocol$ = serialPortConfiguration.protocol$

		aa.serialEvent = CreateObject("roAssociativeArray")
		aa.serialEvent.port$ = port$
		aa.serialEvent.protocol$ = protocol$
		
	    if protocol$ = "Binary" then
			aa.serialEvent.inputSpec = ConvertToByteArray(serial$)
			aa.serialEvent.asciiSpec = serial$
		else
			aa.serialEvent.serial$ = serial$
		endif
		
	    bsp.CreateSerial(bsp, aa.serialEvent.port$, false)
				
	else if userEventName$ = "bp900AUserEvent" or userEventName$ = "bp900BUserEvent" or userEventName$ = "bp900CUserEvent" or userEventName$ = "bp200AUserEvent" or userEventName$ = "bp200BUserEvent" or userEventName$ = "bp200CUserEvent" then
	
		aa.bpEvent = CreateObject("roAssociativeArray")
		
		aa.bpEvent.buttonPanelIndex% = int(val(userEvent.parameters.buttonPanelIndex.GetText()))
		aa.bpEvent.buttonNumber$ = userEvent.parameters.buttonNumber.GetText()
		
		bsp.ConfigureBPInput(aa.bpEvent.buttonPanelIndex%, aa.bpEvent.buttonNumber$)
		
	else if userEventName$ = "gpioUserEvent" then
	
		aa.gpioUserEvent% = int(val(userEvent.parameters.parameter.GetText()))
	
	endif
	
End Sub


Sub newBaseTemplateItem(templateItem As Object, templateItemXML As Object)

	templateItem.type$ = templateItemXML.GetName()
	templateItem.x% = int(val(templateItemXML.x.GetText()))
	templateItem.y% = int(val(templateItemXML.y.GetText()))
	templateItem.width% = int(val(templateItemXML.width.GetText()))
	templateItem.height% = int(val(templateItemXML.height.GetText()))
	templateItem.layer% = int(val(templateItemXML.layer.GetText()))

End Sub


Sub ParseTemplateWidgets(item As Object, itemXML As Object)
	
	' text widget items
	item.numberOfLines% = int(val(itemXML.textWidget.numberOfLines.GetText()))
	
	item.rotation$ = "0"
	ele = itemXML.textWidget.GetNamedElements("rotation")
	if ele.Count() = 1 then
		rotation$ = ele[0].GetText()
		if rotation$ = "90" then
			item.rotation$ = "270"
		else if rotation$ = "180" then
			item.rotation$ = "180"
		else if rotation$ = "270" then
			item.rotation$ = "90"
		endif
	endif

	item.alignment$ = "left"
	ele = itemXML.textWidget.GetNamedElements("alignment")
	if ele.Count() = 1 then
		alignment$ = ele[0].GetText()
		if alignment$ = "center" then
			item.alignment$ = "center"
		else if alignment$ = "right" then
			item.alignment$ = "right"
		endif
	endif

	' widget items
	item.foregroundTextColor$ = GetHexColor(itemXML.widget.foregroundTextColor.GetAttributes())
	item.backgroundTextColor$ = GetHexColor(itemXML.widget.backgroundTextColor.GetAttributes())
	item.font$ = itemXML.widget.font.GetText()
	if item.font$ = "" then item.font$ = "System"

	item.fontSize% = 0
	if type(itemXML.widget.fontSize) = "roXMLList" and itemXML.widget.fontSize.Count() = 1 then
		if itemXML.widget.fontSize.GetText() <> "" then
			item.fontSize% = int(val(itemXML.widget.fontSize.GetText()))
		endif
	endif

	item.backgroundColorSpecified = false
	if lcase(itemXML.backgroundColorSpecified.GetText()) = "true" then
		item.backgroundColorSpecified = true
	endif

End Sub


Sub newTextTemplateItem(templateItem As Object, templateItemXML As Object)

	' fill in base class members
	newBaseTemplateItem(templateItem, templateItemXML)

	ParseTemplateWidgets(templateItem, templateItemXML)

End Sub


Sub newConstantTextTemplateItem(bsp As Object, templateItems As Object, templateItemXML As Object)

	templateItem = { }
	
	newTextTemplateItem(templateItem, templateItemXML)
	
	templateItem.textString$ = templateItemXML.text.GetText()

	templateItems.push(templateItem)

End Sub


Sub newSystemVariableTextTemplateItem(bsp As Object, templateItems As Object, templateItemXML As Object)

	templateItem = { }
	
	newTextTemplateItem(templateItem, templateItemXML)
	
	templateItem.systemVariableType$ = templateItemXML.systemVariable.GetText()

	templateItems.push(templateItem)

End Sub


Sub newMediaCounterTextTemplateItem(bsp As Object, templateItems As Object, templateItemXML As Object)

	templateItem = { }
	
	newTextTemplateItem(templateItem, templateItemXML)
	
	fileName$ = templateItemXML.fileName.GetText()
	templateItem.userVariable = bsp.GetUserVariable(fileName$)
	if type(templateItem.userVariable) <> "roAssociativeArray" then
	    bsp.diagnostics.PrintDebug("Media counter variable " + fileName$ + " not found.")
	    bsp.logging.WriteDiagnosticLogEntry(bsp.diagnosticCodes.EVENT_MEDIA_COUNTER_VARIABLE_NOT_FOUND, fileName$)
	endif

	templateItems.push(templateItem)

End Sub


Sub newUserVariableTextTemplateItem(bsp As Object, templateItems As Object, templateItemXML As Object)

	templateItem = { }
	
	newTextTemplateItem(templateItem, templateItemXML)
	
	name$ = templateItemXML.name.GetText()
	templateItem.userVariable = bsp.GetUserVariable(name$)
	if type(templateItem.userVariable) <> "roAssociativeArray" then
	    bsp.diagnostics.PrintDebug("User variable " + name$ + " not found.")
	    bsp.logging.WriteDiagnosticLogEntry(bsp.diagnosticCodes.EVENT_USER_VARIABLE_NOT_FOUND, name$)
	endif

	templateItems.push(templateItem)

End Sub


Function newLiveTextDataEntryTemplateItem(bsp As Object, templateItems As Object, templateItemXML As Object)

	templateItem = { }
	
	newTextTemplateItem(templateItem, templateItemXML)
	
	liveDataFeedName$ = templateItemXML.liveDataFeedName.GetText()
	templateItem.liveDataFeed = bsp.liveDataFeeds.Lookup(liveDataFeedName$)

	return templateItem

End Function


Sub newIndexedLiveTextDataEntryTemplateItem(bsp As Object, templateItems As Object, templateItemXML As Object)

	templateItem = newLiveTextDataEntryTemplateItem(bsp, templateItems, templateItemXML)

	index$ = templateItemXML.index.GetText()
	if index$ <> "" then
		' old style index was zero based; new style is 1 based.
		index% = int(val(index$))
		index% = index% + 1
		index$ = StripLeadingSpaces(str(index%))
		templateItem.index = newTextParameterValue(index$)
	else
		templateItem.index = newParameterValue(bsp, templateItemXML.indexSpec.parameterValue)
	endif

	templateItems.push(templateItem)

End Sub


Sub newTitledLiveTextDataEntryTemplateItem(bsp As Object, templateItems As Object, templateItemXML As Object)

	templateItem = newLiveTextDataEntryTemplateItem(bsp, templateItems, templateItemXML)

	title$ = templateItemXML.title.GetText()
	if title$ <> "" then
		templateItem.title = newTextParameterValue(title$)
	else
		templateItem.title = newParameterValue(bsp, templateItemXML.titleSpec.parameterValue)
	endif

	templateItems.push(templateItem)

End Sub


Function newSimpleRSSTextTemplateItem(bsp As Object, templateItems As Object, templateItemXML As Object)

	templateItem = { }
	
	newTextTemplateItem(templateItem, templateItemXML)

	templateItem.id$ = templateItemXML.id.GetText()
	templateItem.elementName$ = templateItemXML.elementName.GetText()
	
	templateItems.push(templateItem)

	return templateItem

End Function


Sub newImageTemplateItem(bsp As Object, templateItems As Object, templateItemXML As Object)

	templateItem = { }
	
	newBaseTemplateItem(templateItem, templateItemXML)

	templateItem.fileName$ = templateItemXML.fileName.GetText()

	templateItems.push(templateItem)

End Sub


Function newMRSSTextTemplateItem(bsp As Object, templateItems As Object, templateItemXML As Object) As Object

	templateItem = { }
	
	newTextTemplateItem(templateItem, templateItemXML)
	
	templateItems.push(templateItem)

	return templateItem

End Function


Function newMRSSImageTemplateItem(bsp As Object, templateItems As Object, templateItemXML As Object) As Object

	templateItem = { }
	
	newBaseTemplateItem(templateItem, templateItemXML)
		
	templateItems.push(templateItem)

	return templateItem

End Function


Sub newTemplateItem(bsp As Object, state As Object, templateItems As Object, templateItemXML As Object)

	name$ = templateItemXML.GetName()

	if name$ = "constantTextTemplateItem" then
		
		newConstantTextTemplateItem(bsp, templateItems, templateItemXML)

	else if name$ = "systemVariableTextTemplateItem" then
	
		newSystemVariableTextTemplateItem(bsp, templateItems, templateItemXML)

	else if name$ = "mediaCounterTemplateItem" then

		newMediaCounterTextTemplateItem(bsp, templateItems, templateItemXML)
	
	else if name$ = "userVariableTemplateItem" then

		newUserVariableTextTemplateItem(bsp, templateItems, templateItemXML)

	else if name$ = "indexedLiveTextDataEntryTemplateItem" then

		newIndexedLiveTextDataEntryTemplateItem(bsp, templateItems, templateItemXML)

	else if name$ = "titledLiveTextDataEntryTemplateItem" then

		newTitledLiveTextDataEntryTemplateItem(bsp, templateItems, templateItemXML)

	else if name$ = "imageTemplateItem" then

		newImageTemplateItem(bsp, templateItems, templateItemXML)

	else if name$ = "simpleRSSTextTemplateItem" then

		templateItem = newSimpleRSSTextTemplateItem(bsp, templateItems, templateItemXML)

		if type(state.simpleRSSTextTemplateItems) <> "roAssociativeArray" then
			state.simpleRSSTextTemplateItems = { }
		endif

		simpleRSS = state.simpleRSSTextTemplateItems.Lookup(templateItem.id$)
		if type(simpleRSS) <> "roAssociativeArray" then
			simpleRSS = { }
			simpleRSS.currentIndex% = 0
			simpleRSS.liveDataFeed = templateItem.liveDataFeed
			simpleRSS.displayTime% = int(val(templateItemXML.displayTime.GetText()))

			rssLiveDataFeedNamesXMLList = templateItemXML.GetNamedElements("rssLiveDataFeedName")
			if type(rssLiveDataFeedNamesXMLList) = "roXMLList" and rssLiveDataFeedNamesXMLList.Count() > 0 then
				simpleRSS.rssLiveDataFeeds = CreateObject("roArray", rssLiveDataFeedNamesXMLList.Count(), true)
				for each rssLiveDataFeedNameXML in rssLiveDataFeedNamesXMLList
					liveDataFeedName$ = rssLiveDataFeedNameXML.GetText()
					liveDataFeed = bsp.liveDataFeeds.Lookup(liveDataFeedName$)
					if type(liveDataFeed) = "roAssociativeArray" then
						simpleRSS.rssLiveDataFeeds.push(liveDataFeed)
					endif
				next
			endif
			simpleRSS.currentLiveDataFeedIndex% = 0

			simpleRSS.items = CreateObject("roArray", 1, true)

			state.simpleRSSTextTemplateItems.AddReplace(templateItem.id$, simpleRSS)
		endif

		simpleRSS.items.push(templateItem)

	else if name$ = "mrssTextTemplateItem" then

		elementName$ = templateItemXML.elementName.GetText()

		templateItem = newMRSSTextTemplateItem(bsp, templateItems, templateItemXML)

		if elementName$ = "title" then
			state.mrssTitleTemplateItem = templateItem
		else if elementName$ = "description" then
			state.mrssDescriptionTemplateItem = templateItem
		endif

	else if name$ = "mrssImageTemplateItem" then

		state.mrssImageTemplateItem = newMRSSImageTemplateItem(bsp, templateItems, templateItemXML)

	endif

End Sub


Sub ParseTemplateBackgroundImageXML(bsp As Object, state As Object, playlistItemXML As Object)

    backgroundImageXML = playlistItemXML.backgroundImage
	if backgroundImageXML.Count() = 1 then
		backgroundImageFileElement = backgroundImageXML[0]
		backgroundImageAttributes = backgroundImageFileElement.GetAttributes()
		state.backgroundImage$ = backgroundImageAttributes.Lookup("name")

		if backgroundImageFileElement.HasAttribute("width") then
			state.backgroundImageWidth% = int(val(backgroundImageAttributes.Lookup("width")))
		else
			state.backgroundImageWidth% = -1
		endif

		if backgroundImageFileElement.HasAttribute("height") then
			state.backgroundImageHeight% = int(val(backgroundImageAttributes.Lookup("height")))
		else
			state.backgroundImageHeight% = -1
		endif

	else
		state.backgroundImage$ = ""
	endif
	state.backgroundImageUserVariable = bsp.GetUserVariable(state.backgroundImage$)

End Sub


Sub SetTemplateHandlers(state As Object)

    state.HStateEventHandler = STTemplatePlayingEventHandler
    state.MediaItemEventHandler = MediaItemEventHandler
	state.ExecuteTransition = ExecuteTransition
	state.GetNextStateName = GetNextStateName
    state.UpdatePreviousCurrentStateNames = UpdatePreviousCurrentStateNames
    state.LaunchTimer = LaunchTimer
    state.ConfigureBPButtons = ConfigureBPButtons
    state.PreloadItem = PreloadItem
	state.SetBackgroundImageSizeLocation = SetBackgroundImageSizeLocation
	state.ScaleBackgroundImageToFit = ScaleBackgroundImageToFit

	state.SetupTemplateMRSS = SetupTemplateMRSS
	state.GetNextMRSSTemplateItem = GetNextMRSSTemplateItem
	state.GetMRSSTemplateItem = GetMRSSTemplateItem
	state.RedisplayTemplateItems = RedisplayTemplateItems
	state.BuildTemplateItems = BuildTemplateItems
	state.BuildTemplateItem = BuildTemplateItem
	state.BuildTextTemplateItem = BuildTextTemplateItem
	state.TemplateUsesAnyUserVariable = TemplateUsesAnyUserVariable
	state.TemplateUsesUserVariable = TemplateUsesUserVariable
	state.TemplateUsesSystemVariable = TemplateUsesSystemVariable
	state.TemplateFeedRetrieved = TemplateFeedRetrieved
	state.RestartFetchFeedTimer = RestartFetchFeedTimer

End Sub


Sub newTemplatePlaylistItem(bsp As Object, playlistItemXML As Object, state As Object)

	ParseTemplateBackgroundImageXML(bsp, state, playlistItemXML)

	' retrieve mrss live data feed names
	mrssLiveDataFeedNamesXMLList = playlistItemXML.GetNamedElements("mrssLiveDataFeedName")
	if type(mrssLiveDataFeedNamesXMLList) = "roXMLList" and mrssLiveDataFeedNamesXMLList.Count() > 0 then
		state.mrssActive = true
		state.mrssLiveDataFeeds = CreateObject("roArray", mrssLiveDataFeedNamesXMLList.Count(), true)
		for each mrssLiveDataFeedNameXML in mrssLiveDataFeedNamesXMLList
			liveDataFeedName$ = mrssLiveDataFeedNameXML.GetText()
			liveDataFeed = bsp.liveDataFeeds.Lookup(liveDataFeedName$)
			if type(liveDataFeed) = "roAssociativeArray" then
				state.mrssLiveDataFeeds.push(liveDataFeed)
			endif
		next
	else
		state.mrssActive = false
	endif

	' retrieve template items
	state.templateItems = CreateObject("roArray", 1, true)	
	childElements = playlistItemXML.GetChildElements()
	for each childElement in childElements
		newTemplateItem(bsp, state, state.templateItems, childElement)
	next

	SetTemplateHandlers(state)

End Sub


Sub newTemplatePlaylistItemFromLiveTextPlaylistItem(bsp As Object, playlistItemXML As Object, state As Object)

	ParseTemplateBackgroundImageXML(bsp, state, playlistItemXML)

	state.mrssActive = false

	' compatibility with old data format
	liveDataFeedUpdateInterval% = 600
	if playlistItemXML.liveTextRSSUpdateInterval.GetText() <> "" then
		liveDataFeedUpdateInterval% = int(val(playlistItemXML.liveTextRSSUpdateInterval.GetText()))
	endif

    textItemsXML = playlistItemXML.textItem

	textItems = CreateObject("roArray", 1, true)
    for each textItemXML in textItemsXML
		newTextItem(bsp, textItems, textItemXML, liveDataFeedUpdateInterval%)
    next

	state.templateItems = CreateObject("roArray", 1, true)	

	for each textItem in textItems

		templateItem = { }	
		newTextTemplateItemFromTextItem(templateItem, textItem)
		
		if textItem.textType$ = "constant" then
			templateItem.type$ = "constantTextTemplateItem"
			templateItem.textString$ = textItem.textString$
		else if textItem.textType$ = "system" then
			templateItem.type$ = "systemVariableTextTemplateItem"
			templateItem.systemVariableType$ = textItem.systemVariableType$
		else if textItem.textType$ = "indexedLiveTextData" then
			templateItem.type$ = "indexedLiveTextDataEntryTemplateItem"
			templateItem.liveDataFeed = textItem.liveDataFeed

			' old style index was zero based; new style is 1 based.
			index% = textItem.index%
			index% = index% + 1
			index$ = StripLeadingSpaces(str(index%))
			templateItem.index = newTextParameterValue(index$)
		else if textItem.textType$ = "titledLiveTextData" then
			templateItem.type$ = "titledLiveTextDataEntryTemplateItem"
			templateItem.liveDataFeed = textItem.liveDataFeed
			templateItem.title = newTextParameterValue(textItem.title$)
		else if textItem.textType$ = "mediaCounter" then
			templateItem.type$ = "mediaCounterTemplateItem"
			templateItem.userVariable = textItem.userVariable
		else if textItem.textType$ = "userVariable" then
			templateItem.type$ = "userVariableTemplateItem"
			templateItem.userVariable = textItem.userVariable
		endif

		state.templateItems.push(templateItem)

	next

	SetTemplateHandlers(state)

End Sub


Sub newBaseTemplateItemFromTextItem(templateItem As Object, textItem As Object)

	templateItem.x% = textItem.x%
	templateItem.y% = textItem.y%
	templateItem.width% = textItem.width%
	templateItem.height% = textItem.height%
	templateItem.layer% = 1

End Sub


Sub newTextTemplateItemFromTextItem(templateItem As Object, textItem As Object)

	' fill in base class members
	newBaseTemplateItemFromTextItem(templateItem, textItem)

	' text widget items
	templateItem.numberOfLines% = textItem.numberOfLines%
	templateItem.rotation$ = textItem.rotation$
	templateItem.alignment$ = textItem.alignment$

	' widget items
	templateItem.foregroundTextColor$ = textItem.foregroundTextColor$
	templateItem.backgroundTextColor$ = textItem.backgroundTextColor$
	templateItem.font$ = textItem.font$
	templateItem.fontSize% = textItem.fontSize%

	templateItem.backgroundColorSpecified = textItem.backgroundColorSpecified

End Sub


Sub newTextItem(bsp As Object, textItems As Object, textItemXML As Object, liveDataFeedUpdateInterval% As Integer)

	textItem = CreateObject("roAssociativeArray")
	
	textItem.x% = int(val(textItemXML.x.GetText()))
	textItem.y% = int(val(textItemXML.y.GetText()))
	textItem.width% = int(val(textItemXML.width.GetText()))
	textItem.height% = int(val(textItemXML.height.GetText()))

	if textItemXML.textItemConstant.Count() = 1 then
		textItem.textType$ = "constant"
		textItemConstantElement = textItemXML.textItemConstant[0]
		textItem.textString$ = textItemConstantElement.text.GetText()
	else if textItemXML.textItemSystemVariable.Count() = 1 then
		textItem.textType$ = "system"
		textItemSystemVariableElement = textItemXML.textItemSystemVariable[0]
		textItem.systemVariableType$ = textItemSystemVariableElement.systemVariable.GetText()
	else if textItemXML.textItemIndexedLiveTextDataEntry.Count() = 1 then
		textItem.textType$ = "indexedLiveTextData"
		textItemIndexedLiveTextDataEntryElement = textItemXML.textItemIndexedLiveTextDataEntry[0]
		index$ = textItemIndexedLiveTextDataEntryElement.Index.GetText()
		textItem.index% = int(val(index$))
		if textItemIndexedLiveTextDataEntryElement.liveDataFeedName.GetText() <> "" then
			liveDataFeedName$ = textItemIndexedLiveTextDataEntryElement.liveDataFeedName.GetText()
			textItem.liveDataFeed = bsp.liveDataFeeds.Lookup(liveDataFeedName$)
		else
			if type(textItemIndexedLiveTextDataEntryElement.LiveTextDataUrlSpec) = "roXMLList" and textItemIndexedLiveTextDataEntryElement.LiveTextDataUrlSpec.Count() = 1 then
				url = newParameterValue(bsp, textItemIndexedLiveTextDataEntryElement.LiveTextDataUrlSpec.parameterValue)
			else
				liveTextDataUrl$ = textItemIndexedLiveTextDataEntryElement.LiveTextDataUrl.GetText()
				url = newTextParameterValue(liveTextDataUrl$)
			endif
			liveDataFeed = newLiveDataFeedFromOldDataFormat(url, liveDataFeedUpdateInterval%)
			bsp.liveDataFeeds.AddReplace(liveDataFeed.name$, liveDataFeed)
		endif
	else if textItemXML.textItemTitledLiveTextDataEntry.Count() = 1 then
		textItem.textType$ = "titledLiveTextData"
		textItemTitledLiveTextDataEntryElement = textItemXML.textItemTitledLiveTextDataEntry[0]
		textItem.title$ = textItemTitledLiveTextDataEntryElement.Title.GetText()
		if textItemTitledLiveTextDataEntryElement.liveDataFeedName.GetText() <> "" then
			liveDataFeedName$ = textItemTitledLiveTextDataEntryElement.liveDataFeedName.GetText()
			textItem.liveDataFeed = bsp.liveDataFeeds.Lookup(liveDataFeedName$)
		else
			if type(textItemTitledLiveTextDataEntryElement.LiveTextDataUrlSpec) = "roXMLList" and textItemTitledLiveTextDataEntryElement.LiveTextDataUrlSpec.Count() = 1 then
				url = newParameterValue(bsp, textItemTitledLiveTextDataEntryElement.LiveTextDataUrlSpec.parameterValue)
			else
				liveTextDataUrl$ = textItemTitledLiveTextDataEntryElement.LiveTextDataUrl.GetText()
				url = newTextParameterValue(liveTextDataUrl$)
			endif
			liveDataFeed = newLiveDataFeedFromOldDataFormat(url, liveDataFeedUpdateInterval%)
			bsp.liveDataFeeds.AddReplace(liveDataFeed.name$, liveDataFeed)
		endif
	else if textItemXML.textItemMediaCounter.Count() = 1 then
		textItem.textType$ = "mediaCounter"
		fileName$ = textItemXML.textItemMediaCounter.fileName.GetText()
		textItem.userVariable = bsp.GetUserVariable(fileName$)
		if type(textItem.userVariable) <> "roAssociativeArray" then
		    bsp.diagnostics.PrintDebug("Media counter variable " + fileName$ + " not found.")
		    bsp.logging.WriteDiagnosticLogEntry(bsp.diagnosticCodes.EVENT_MEDIA_COUNTER_VARIABLE_NOT_FOUND, fileName$)
		endif
	else if textItemXML.textItemUserVariable.Count() = 1 then
		textItem.textType$ = "userVariable"
		userVariableName$ = textItemXML.textItemUserVariable.name.GetText()
		textItem.userVariable = bsp.GetUserVariable(userVariableName$)
		if type(textItem.userVariable) <> "roAssociativeArray" then
		    bsp.diagnostics.PrintDebug("User variable " + userVariableName$ + " not found.")
		    bsp.logging.WriteDiagnosticLogEntry(bsp.diagnosticCodes.EVENT_USER_VARIABLE_NOT_FOUND, fileName$)
		endif
	else
		stop
	endif

	ParseTemplateWidgets(textItem, textItemXML)

	textItems.push(textItem)

End Sub

	
Sub newAudioInPlaylistItem(bsp As Object, playlistItemXML As Object, state As Object)
	
    file = playlistItemXML.file
    fileAttrs = file.GetAttributes()
    state.imageFileName$ = fileAttrs["name"]
	state.imageUserVariable = bsp.GetUserVariable(state.imageFileName$)

    state.HStateEventHandler = STAudioInPlayingEventHandler
    state.MediaItemEventHandler = MediaItemEventHandler
	state.ExecuteTransition = ExecuteTransition
	state.GetNextStateName = GetNextStateName
    state.UpdatePreviousCurrentStateNames = UpdatePreviousCurrentStateNames
    state.LaunchTimer = LaunchTimer
    state.ConfigureBPButtons = ConfigureBPButtons

End Sub


Sub newSignChannelPlaylistItem(playlistItemXML As Object, state As Object)

    state.timeOnScreen% = int(val(playlistItemXML.timeOnScreen.GetText()))
    state.rssURL$ = ""
	state.slideTransition% = 15
	state.isDynamicPlaylist = false

    state.HStateEventHandler = STPlayingMediaRSSEventHandler
    state.MediaItemEventHandler = MediaItemEventHandler
    state.ExecuteTransition = ExecuteTransition
    state.GetNextStateName = GetNextStateName
    state.UpdatePreviousCurrentStateNames = UpdatePreviousCurrentStateNames
    state.LaunchTimer = LaunchTimer
    state.ShowFeed = ShowFeed
    state.RestartFetchFeedTimer = RestartFetchFeedTimer
    state.PreloadItem = PreloadItem
    state.ConfigureBPButtons = ConfigureBPButtons
    
End Sub


Sub newRSSImagePlaylistItem(bsp As Object, playlistItemXML As Object, state As Object)

    rssSpec = playlistItemXML.rssSpec
    rssSpecAttrs = rssSpec.GetAttributes()

	state.isDynamicPlaylist = false
	if rssSpecAttrs.DoesExist("usesBSNDynamicPlaylist") then
		usesDynamicPlaylist = rssSpecAttrs.Lookup("usesBSNDynamicPlaylist")
		if lcase(usesDynamicPlaylist) = "true" then
			state.isDynamicPlaylist = true
		endif
	endif
    
	if rssSpecAttrs.DoesExist("url") then
		state.rssURL$ = rssSpecAttrs["url"]
	else
		url = newParameterValue(bsp, playlistItemXML.urlSpec.parameterValue)
		state.rssURL$ = url.GetCurrentParameterValue()
	endif

    state.HStateEventHandler = STPlayingMediaRSSEventHandler
    state.MediaItemEventHandler = MediaItemEventHandler
    state.ExecuteTransition = ExecuteTransition
    state.GetNextStateName = GetNextStateName
    state.UpdatePreviousCurrentStateNames = UpdatePreviousCurrentStateNames
    state.LaunchTimer = LaunchTimer
    state.ShowFeed = ShowFeed
    state.RestartFetchFeedTimer = RestartFetchFeedTimer
    state.PreloadItem = PreloadItem
    state.ConfigureBPButtons = ConfigureBPButtons
    
End Sub


Sub	newLocalPlaylistItem(bsp As Object, playlistItemXML As Object, state As Object)

    attrs = playlistItemXML.defaultPlaylist.mediaRSSSpec.GetAttributes()
    state.rssURL$ = attrs["url"]

	devicePlaylists = playlistItemXML.devicePlaylist
	for each devicePlaylist in devicePlaylists
		deviceName$ = devicePlaylist.deviceName.GetText()
		attrs = devicePlaylist.dynamicPlaylist.mediaRSSSpec.GetAttributes()
		dynamicPlaylistUrl$ = attrs["url"]
		if deviceName$ = bsp.sysInfo.deviceUniqueID$ then
		    state.rssURL$ = dynamicPlaylistUrl$
			exit for
		endif
	next

	state.isDynamicPlaylist = true

	state.HStateEventHandler = STPlayingMediaRSSEventHandler
	state.MediaItemEventHandler = MediaItemEventHandler
	state.ExecuteTransition = ExecuteTransition
	state.GetNextStateName = GetNextStateName
	state.UpdatePreviousCurrentStateNames = UpdatePreviousCurrentStateNames
	state.LaunchTimer = LaunchTimer
	state.ShowFeed = ShowFeed
	state.RestartFetchFeedTimer = RestartFetchFeedTimer
	state.PreloadItem = PreloadItem
	state.ConfigureBPButtons = ConfigureBPButtons
	state.GetAnyMediaRSSTransition = GetAnyMediaRSSTransition

End Sub


Sub newTripleUSBPlaylistItem(playlistItemXML As Object, sign As Object, state As Object)

	state.boseProductName$ = playlistItemXML.boseProductName.GetText()
	state.noiseThreshold% = int(val(playlistItemXML.noiseThreshold.GetText()))
    state.tripleUSBPort$ = sign.tripleUSBPort$
    
	boseProductSpec = state.bsp.GetBoseProductSpec(state.boseProductName$)
	if type(boseProductSpec) = "roAssociativeArray" then
	    boseProductInSign = sign.boseProducts.Lookup(state.boseProductName$)
	    state.boseProductPort$ = boseProductInSign.port$
	    state.volumeTable = boseProductSpec.volumeTable
	else
		state.boseProductPort$ = ""
		state.volumeTable = invalid
    endif
    
	state.HStateEventHandler = STTripleUSBEventHandler
	state.ExecuteTransition = ExecuteTransition
	state.GetNextStateName = GetNextStateName
    state.UpdatePreviousCurrentStateNames = UpdatePreviousCurrentStateNames
	state.SendVolumeCommand = SendVolumeCommand

End Sub


Function GetBoolFromXML(xmlValue$ As String) As Boolean

	value$ = lcase(xmlValue$)
	if value$ = "true" then
		return true
	else
		return false
	endif

End Function


Sub SetStateEvent(bsp As Object, stateEvent as Object, eventXML As Object)

	userEventsList = eventXML.userEvent
	if userEventsList.Count() = 0 then print "Invalid XML file - userEvent not found" : stop
	for each userEvent in userEventsList

		userEventName$ = userEvent.name.GetText()

		if userEventName$ = "gpioUserEvent" then
			stateEvent.gpioUserEvent$ = userEvent.parameters.parameter.GetText()        
		else if userEventName$ = "bp900AUserEvent" or userEventName$ = "bp900BUserEvent" or userEventName$ = "bp900CUserEvent" or userEventName$ = "bp200AUserEvent" or userEventName$ = "bp200BUserEvent" or userEventName$ = "bp200CUserEvent" then
			stateEvent.bpUserEventButtonNumber$ = userEvent.parameters.buttonNumber.GetText()
			stateEvent.bpUserEventButtonPanelIndex$ = userEvent.parameters.buttonPanelIndex.GetText()
			bpIndex% = int(val(stateEvent.bpUserEventButtonPanelIndex$))
			bsp.ConfigureBPInput(bpIndex%, stateEvent.bpUserEventButtonNumber$)
		else if userEventName$ = "serial" then
			stateEvent.serialUserEventPort$ = userEvent.parameters.parameter.GetText()
			stateEvent.serialUserEventSerialEvent$ = userEvent.parameters.parameter2.GetText()
			bsp.CreateSerial(bsp, stateEvent.serialUserEventPort$, false)
		else if userEventName$ = "udp" then
			stateEvent.udpUserEvent$ = userEvent.parameters.parameter.GetText()
		else if userEventName$ = "keyboard" then
			stateEvent.keyboardUserEvent$ = userEvent.parameters.parameter.GetText()
		endif

	next

End Sub


Sub newMediaListPlaylistItem(bsp As Object, zoneHSM As Object, playlistItemXML As Object, state As Object)

	if zoneHSM.type$ <> "EnhancedAudio" then

		if type(bsp.mediaListInactivity) <> "roAssociativeArray" then
			bsp.mediaListInactivity = CreateObject("roAssociativeArray")
			bsp.mediaListInactivity.mediaListStates = CreateObject("roList")
		endif

		bsp.mediaListInactivity.mediaListStates.AddTail(state)
	
	endif
		
	state.mediaType$ = playlistItemXML.mediaType.GetText()
	
	state.advanceOnMediaEnd = GetBoolFromXML(playlistItemXML.advanceOnMediaEnd.GetText())
	state.advanceOnImageTimeout = GetBoolFromXML(playlistItemXML.advanceOnImageTimeout.GetText())
	state.playFromBeginning = GetBoolFromXML(playlistItemXML.playFromBeginning.GetText())
	state.shuffle = GetBoolFromXML(playlistItemXML.shuffle.GetText())

	imageTimeout$ = lcase(playlistItemXML.imageTimeout.GetText())
	if imageTimeout$ = "" then
		state.imageTimeout = 5000
	else
		state.imageTimeout = val(imageTimeout$) * 1000
	endif
	
	if type(playlistItemXML.next) = "roXMLList" and playlistItemXML.next.Count() = 1 then
	
		state.nextNavigation = CreateObject("roAssociativeArray")
		SetStateEvent(bsp, state.nextNavigation, playlistItemXML.next)

'		nextNavigation = state.nextNavigation
		
'		userEventsList = playlistItemXML.next.userEvent
'		if userEventsList.Count() = 0 then print "Invalid XML file - userEvent not found" : stop
'		for each userEvent in userEventsList

'			userEventName$ = userEvent.name.GetText()

'			if userEventName$ = "gpioUserEvent" then
'				nextNavigation.gpioUserEvent$ = userEvent.parameters.parameter.GetText()        
'			else if userEventName$ = "bp900AUserEvent" or userEventName$ = "bp900BUserEvent" or userEventName$ = "bp900CUserEvent" or userEventName$ = "bp200AUserEvent" or userEventName$ = "bp200BUserEvent" or userEventName$ = "bp200CUserEvent" then
'				nextNavigation.bpUserEventButtonNumber$ = userEvent.parameters.buttonNumber.GetText()
'				nextNavigation.bpUserEventButtonPanelIndex$ = userEvent.parameters.buttonPanelIndex.GetText()
'				bpIndex% = int(val(nextNavigation.bpUserEventButtonPanelIndex$))
'				bsp.ConfigureBPInput(bpIndex%, nextNavigation.bpUserEventButtonNumber$)
'			else if userEventName$ = "serial" then
'				nextNavigation.serialUserEventPort$ = userEvent.parameters.parameter.GetText()
'				nextNavigation.serialUserEventSerialEvent$ = userEvent.parameters.parameter2.GetText()
'			    bsp.CreateSerial(bsp, nextNavigation.serialUserEventPort$, false)
'			else if userEventName$ = "keyboard" then
'				nextNavigation.keyboardUserEvent$ = userEvent.parameters.parameter.GetText()
'			endif

'		next
		
	endif
		
	if type(playlistItemXML.previous) = "roXMLList" and playlistItemXML.previous.Count() = 1 then
	
		state.previousNavigation = CreateObject("roAssociativeArray")
		SetStateEvent(bsp, state.previousNavigation, playlistItemXML.previous)

'		previousNavigation = state.previousNavigation
		
'		userEventsList = playlistItemXML.previous.userEvent
'		if userEventsList.Count() = 0 then print "Invalid XML file - userEvent not found" : stop
'		for each userEvent in userEventsList

'			userEventName$ = userEvent.name.GetText()

'			if userEventName$ = "gpioUserEvent" then
'				previousNavigation.gpioUserEvent$ = userEvent.parameters.parameter.GetText()        
'			else if userEventName$ = "bp900AUserEvent" or userEventName$ = "bp900BUserEvent" or userEventName$ = "bp900CUserEvent" or userEventName$ = "bp200AUserEvent" or userEventName$ = "bp200BUserEvent" or userEventName$ = "bp200CUserEvent" then
'				previousNavigation.bpUserEventButtonNumber$ = userEvent.parameters.buttonNumber.GetText()
'				previousNavigation.bpUserEventButtonPanelIndex$ = userEvent.parameters.buttonPanelIndex.GetText()
'				bpIndex% = int(val(previousNavigation.bpUserEventButtonPanelIndex$))
'				bsp.ConfigureBPInput(bpIndex%, previousNavigation.bpUserEventButtonNumber$)
'			else if userEventName$ = "serial" then
'				previousNavigation.serialUserEventPort$ = userEvent.parameters.parameter.GetText()
'				previousNavigation.serialUserEventSerialEvent$ = userEvent.parameters.parameter2.GetText()
'			    bsp.CreateSerial(bsp, previousNavigation.serialUserEventPort$, false)
'			else if userEventName$ = "keyboard" then
'				previousNavigation.keyboardUserEvent$ = userEvent.parameters.parameter.GetText()
'			endif
'		
'		next

	endif
		
	if state.mediaType$ = "image" then
        zoneHSM.numImageItems% = zoneHSM.numImageItems% + 1
	    imageItemList = playlistItemXML.files.imageItem
		if type(imageItemList) <> "roXMLList" then print "Invalid XML file - item list not found" : stop
		state.numItems% = imageItemList.Count()
		state.items = CreateObject("roArray", state.numItems%, true)
		for each imageItem in imageItemList
		    item = CreateObject("roAssociativeArray")
			newImagePlaylistItem(bsp, imageItem, state, item)
			state.items.push(item)
		next
	else if state.mediaType$ = "video" then
	    videoItemList = playlistItemXML.files.videoItem
		if type(videoItemList) <> "roXMLList" then print "Invalid XML file - item list not found" : stop
		state.numItems% = videoItemList.Count()
		state.items = CreateObject("roArray", state.numItems%, true)
		for each videoItem in videoItemList
		    item = CreateObject("roAssociativeArray")
			newVideoPlaylistItem(bsp, videoItem, state, item)
			state.items.push(item)
		next
	else if state.mediaType$ = "audio" then
	    audioItemList = playlistItemXML.files.audioItem
		if type(audioItemList) <> "roXMLList" then print "Invalid XML file - item list not found" : stop
		state.numItems% = audioItemList.Count()
		state.items = CreateObject("roArray", state.numItems%, true)
		for each audioItem in audioItemList
		    item = CreateObject("roAssociativeArray")
			newAudioPlaylistItem(bsp, audioItem, state, item)
			state.items.push(item)
		next
	endif
	
	state.playbackIndex% = 0

	state.playbackIndices = CreateObject("roArray", state.numItems%, true)
    for i% = 0 to state.numItems%-1
	    state.playbackIndices[i%] = i%
	next

    state.HStateEventHandler = STDisplayingMediaListItemEventHandler
	state.ConfigureIntraStateEventHandlerButton = ConfigureIntraStateEventHandlerButton
	state.LaunchAudio = LaunchAudio
	state.LaunchMixerAudio = LaunchMixerAudio
	state.LaunchVideo = LaunchVideo
	state.DisplayImage = DisplayImage
	state.StartInactivityTimer = StartInactivityTimer
	state.HandleIntraStateEvent = HandleIntraStateEvent
	state.LaunchMediaListPlaybackItem = LaunchMediaListPlaybackItem
	state.AdvanceMediaListPlayback = AdvanceMediaListPlayback
	state.RetreatMediaListPlayback = RetreatMediaListPlayback
	
    state.AddVideoTimeCodeEvent = AddVideoTimeCodeEvent
    state.SetVideoTimeCodeEvents = SetVideoTimeCodeEvents

    state.MediaItemEventHandler = MediaItemEventHandler
	state.ExecuteTransition = ExecuteTransition
	state.GetNextStateName = GetNextStateName
    state.UpdatePreviousCurrentStateNames = UpdatePreviousCurrentStateNames
    state.LaunchTimer = LaunchTimer
    state.PreloadItem = PreloadItem

	state.ConfigureBPButtons = ConfigureBPButtons
	
End Sub


Sub newPlayFilePlaylistItem(bsp As Object, playlistItemXML As Object, state As Object)

	state.filesTable = CreateObject("roAssociativeArray")

	state.mediaType$ = playlistItemXML.mediaType.GetText()

    state.slideTransition% = GetSlideTransitionValue(playlistItemXML.slideTransition.GetText())

    files = playlistItemXML.filesTable.file
    if playlistItemXML.filesTable.file.Count() > 0 then
        for each file in files
		    fileAttrs = file.GetAttributes()
			key$ = fileAttrs["key"]
			fileTableEntry = CreateObject("roAssociativeArray")
			fileTableEntry.fileName$ = fileAttrs["name"]
			fileTableEntry.fileType$ = fileAttrs["type"]
			if fileTableEntry.fileType$ = "video" or fileTableEntry.fileType$ = "audio" then
				fileTableEntry.probeData = GetProbeData(bsp.syncPoolFiles, fileTableEntry.fileName$)
			endif
			fileTableEntry.userVariable = bsp.GetUserVariable(fileTableEntry.fileName$)
			fileTableEntry.videoDisplayMode% = 0
			videoDisplayMode$ = fileAttrs["videoDisplayMode"]
			if videoDisplayMode$ = "3DSBS" then
				fileTableEntry.videoDisplayMode% = 1
			else if videoDisplayMode$ = "3DTOB" then
				fileTableEntry.videoDisplayMode% = 2
			endif
			state.filesTable.AddReplace(key$, fileTableEntry)
        next
    endif

    state.HStateEventHandler = STPlayFileEventHandler
	state.MediaItemEventHandler = MediaItemEventHandler
	state.ExecuteTransition = ExecuteTransition
	state.GetNextStateName = GetNextStateName
    state.UpdatePreviousCurrentStateNames = UpdatePreviousCurrentStateNames
    state.LaunchTimer = LaunchTimer
	state.DisplayImage = DisplayImage
    state.ConfigureBPButtons = ConfigureBPButtons
    state.LaunchVideo = LaunchVideo
    state.SetVideoTimeCodeEvents = SetVideoTimeCodeEvents
	state.LaunchAudio = LaunchAudio
    state.PreloadItem = PreloadItem

End Sub


Sub newStreamPlaylistItem(playlistItemXML As Object, state As Object)

	streamSpecAttrs = playlistItemXML.streamSpec.GetAttributes()
	state.url$ = streamSpecAttrs["url"]

    state.HStateEventHandler = STStreamPlayingEventHandler
	state.MediaItemEventHandler = MediaItemEventHandler
    state.ConfigureBPButtons = ConfigureBPButtons
    state.LaunchTimer = LaunchTimer
	state.ExecuteTransition = ExecuteTransition
	state.GetNextStateName = GetNextStateName
    state.UpdatePreviousCurrentStateNames = UpdatePreviousCurrentStateNames

End Sub


Sub newMjpegStreamPlaylistItem(playlistItemXML As Object, state As Object)

	mjpegSpecAttrs = playlistItemXML.mjpegSpec.GetAttributes()
	state.url$ = mjpegSpecAttrs["url"]
	state.rotation% = int(val(mjpegSpecAttrs["rotation"]))

    state.HStateEventHandler = STMjpegPlayingEventHandler
	state.MediaItemEventHandler = MediaItemEventHandler
    state.ConfigureBPButtons = ConfigureBPButtons
    state.LaunchTimer = LaunchTimer
	state.ExecuteTransition = ExecuteTransition
	state.GetNextStateName = GetNextStateName
    state.UpdatePreviousCurrentStateNames = UpdatePreviousCurrentStateNames

End Sub


Sub newAudioPlaylistItem(bsp As Object, playlistItemXML As Object, state As Object, playlistItemBS As Object)

    newMediaPlaylistItem(bsp, playlistItemXML, state, playlistItemBS)

	playlistItemBS.probeData = GetProbeData(bsp.syncPoolFiles, playlistItemBS.fileName$)

    itemVolume$ = playlistItemXML.volume.GetText()
    if itemVolume$ <> "" then
        playlistItemBS.volume% = int(val(itemVolume$))
    endif
    
    state.HStateEventHandler = STAudioPlayingEventHandler
	state.LaunchAudio = LaunchAudio
	state.LaunchMixerAudio = LaunchMixerAudio
    state.ConfigureBPButtons = ConfigureBPButtons
    
End Sub


Function newTextPlaylistItem(playlistItemXML As Object) As Object

	item = CreateObject("roAssociativeArray")
	
    strings = playlistItemXML.strings

    numTextStrings% = 0
    if strings <> invalid then
        children = strings.GetChildElements()
        if children <> invalid then
            numTextStrings% = children.Count()
        end if
    end if

    item.textStrings = CreateObject("roArray", numTextStrings%, true)

    for each textStringXML in strings.GetChildElements()

        textString = textStringXML.GetText()
        item.textStrings.push(textString)

    next

	item.isRSSFeed = false
	
    return item

End Function


Function newTwitterPlaylistItem(bsp As Object, zoneHSM As Object, playlistItemXML As Object) As Object

	item = CreateObject("roAssociativeArray")
	
    ' read twitter user name
    twitterSpec = playlistItemXML.twitterSpec
    twitterSpecAttrs = twitterSpec.GetAttributes()

	twitterUserName$ = twitterSpecAttrs["userName"]
	jsonUrl$ = "https://api.twitter.com/1.1/statuses/user_timeline.json?screen_name=" + twitterUserName$
	url = newTextParameterValue(jsonUrl$)

	authData = CreateObject("roAssociativeArray")
	authData.AuthType = "OAuth 1.0a"
	authData.AuthToken = twitterSpecAttrs["AuthToken"]
	authData.ConsumerKey = twitterSpecAttrs["BSConsumerKey"]
	authData.EncryptedTwitterSecrets = twitterSpecAttrs["EncryptedTwitterSecrets"]

	if type(twitterSpecAttrs["updateInterval"]) = "roString" then
		updateInterval$ = twitterSpecAttrs["updateInterval"]
		if updateInterval$ = "" then
			updateInterval$ = "300"
		endif
		updateInterval% = int(val(updateInterval$))
	else
		updateInterval% = 300
	endif
	liveDataFeed = newLiveDataFeedWithAuthDataFromOldDataFormat(url, authData, updateInterval%)

	if not bsp.liveDataFeeds.DoesExist(liveDataFeed.name$) then
		liveDataFeed.isJSON = true
		bsp.liveDataFeeds.AddReplace(liveDataFeed.name$, liveDataFeed)
	else
		liveDataFeed = bsp.liveDataFeeds.Lookup(liveDataFeed.name$)
	endif

	item.liveDataFeed = liveDataFeed
    item.rssTitle$ = item.liveDataFeed.name$

	item.twitterUserName$ = twitterSpecAttrs["userName"] + ": "
	item.isRSSFeed = true

    return item
    
End Function


Function newRSSDataFeedPlaylistItem(bsp As Object, playlistItemXML As Object) As Object

	item = CreateObject("roAssociativeArray")
	
	liveDataFeedName$ = playlistItemXML.liveDataFeedName.GetText()
	item.liveDataFeed = bsp.liveDataFeeds.Lookup(liveDataFeedName$)
    item.rssTitle$ = item.liveDataFeed.name$
    
	item.isRSSFeed = true

    return item

End Function


Function newRSSPlaylistItem(bsp As Object, zoneHSM As Object, playlistItemXML As Object) As Object

	item = CreateObject("roAssociativeArray")
	
    rssSpec = playlistItemXML.rssSpec
    rssSpecAttrs = rssSpec.GetAttributes()
    
	url = newTextParameterValue(rssSpecAttrs["url"])

	url$ = url.GetCurrentParameterValue()

    ' determine if this is a twitter feed
	isTwitterFeed = false
    index% = Instr(1, url$, "api.twitter.com")
    if index% > 0 then
		userNameIndex% = Instr(1, url$, "screen_name=")
		if userNameIndex% > 0 then
			isTwitterFeed = true
			item.twitterUserName$ = Mid(url$, userNameIndex% + 12)
			' Be careful if you change the Twitter URL. It must be a normalized form for OAuth
			' authentication to work. (Refer to OAuth docs.)
			jsonUrl$ = "https://api.twitter.com/1/statuses/user_timeline.json?screen_name=" + item.twitterUserName$
			url = newTextParameterValue(jsonUrl$)
		endif
	endif
    
	liveDataFeed = newLiveDataFeedFromOldDataFormat(url, zoneHSM.rssDownloadPeriodicValue%)
	bsp.liveDataFeeds.AddReplace(liveDataFeed.name$, liveDataFeed)

	item.liveDataFeed = liveDataFeed
    item.rssTitle$ = item.liveDataFeed.name$
	item.isRSSFeed = true
	
	if isTwitterFeed then
		liveDataFeed.isJSON = true
	else
		liveDataFeed.isJSON = false
	endif
    
	return item
    
End Function


Sub newBackgroundImagePlaylistItem(bsp As Object, playlistItemXML As Object, state As Object, playlistItemBS As Object)

    newMediaPlaylistItem(bsp, playlistItemXML, state, playlistItemBS)

    state.HStateEventHandler = STDisplayingBackgroundImageEventHandler

End Sub


Function GetViewModeValue(viewModeSpec$ As String) As Integer

    viewMode% = 2
    
    if viewModeSpec$ = "Scale to Fill" then
        viewMode% = 0
    else if viewModeSpec$ = "Letterboxed and Centered" then
        viewMode% = 1
    endif
    
    return viewMode%
    
End Function


Function GetAudioOutputValue(audioOutputSpec$ As String) As Integer

    audioOutput% = 0
    
    if audioOutputSpec$ = "USB Audio" then
        audioOutput% = 1
    else if audioOutputSpec$ = "SPDIF Audio with Stereo PCM (HDMI Audio)" then
        audioOutput% = 2
    else if audioOutputSpec$ = "SPDIF Audio, Raw Multichannel" then
        audioOutput% = 3
    else if audioOutputSpec$ = "Analog Audio with Raw Multichannel on SPDIF" then
        audioOutput% = 4
    endif
    
    return audioOutput%
    
End Function


Function GetAudioModeValue(audioModeSpec$ As String) As Integer

    audioMode% = 0
    
    if audioModeSpec$ = "Multichannel Mixed Down to Stereo" then
        audioMode% = 1
    else if audioModeSpec$ = "No Audio" then
        audioMode% = 2
    else if audioModeSpec$ = "Mono Left Mixdown" then
		audioMode% = 3
	else if audioModeSpec$ = "Mono Right Mixdown" then
		audioMode% = 4
	endif
    
    return audioMode%
    
End Function


Function GetAudioMappingValue(audioMappingSpec$ As String) As Integer

    audioMapping% = 0
    
    if audioMappingSpec$ = "Audio-2" then
        audioMapping% = 1
    else if audioMappingSpec$ = "Audio-3" then
        audioMapping% = 2
    endif
    
    return audioMapping%
    
End Function


Function GetAudioMappingSpan(audioOutput% As Integer, audioMappingSpec$ As String) As Integer

    audioMappingSpan% = 1

    if audioOutput% = 0 and audioMappingSpec$ = "Audio-all" then
        audioMappingSpan% = 3
    endif
    
    return audioMappingSpan%

End Function


Function GetImageModeValue(imageModeSpec$ As String) As Integer

    imageMode% = 1
    
    if imageModeSpec$ = "Center Image" then
        imageMode% = 0
    else if imageModeSpec$ = "Scale to Fill and Crop" then
        imageMode% = 2
    else if imageModeSpec$ = "Scale to Fill" then
        imageMode% = 3
    endif
    
    return imageMode%
    
End Function


Function GetSlideTransitionValue(slideTransitionSpec$ As String) As Integer

    slideTransition% = 0
    
    if slideTransitionSpec$ = "Image wipe from top" then
        slideTransition% = 1
    else if slideTransitionSpec$ = "Image wipe from bottom" then
        slideTransition% = 2
    else if slideTransitionSpec$ = "Image wipe from left" then
        slideTransition% = 3
    else if slideTransitionSpec$ = "Image wipe from right" then
        slideTransition% = 4
    else if slideTransitionSpec$ = "Explode from center" then
        slideTransition% = 5
    else if slideTransitionSpec$ = "Explode from top left" then
        slideTransition% = 6
    else if slideTransitionSpec$ = "Explode from top right" then
        slideTransition% = 7
    else if slideTransitionSpec$ = "Explode from bottom left" then
        slideTransition% = 8
    else if slideTransitionSpec$ = "Explode from bottom right" then
        slideTransition% = 9
    else if slideTransitionSpec$ = "Venetian blinds - vertical" then
        slideTransition% = 10
    else if slideTransitionSpec$ = "Venetian blinds - horizontal" then
        slideTransition% = 11
    else if slideTransitionSpec$ = "Comb effect - vertical" then
        slideTransition% = 12
    else if slideTransitionSpec$ = "Comb effect - horizontal" then
        slideTransition% = 13
    else if slideTransitionSpec$ = "Fade to background color" then
        slideTransition% = 14
    else if slideTransitionSpec$ = "Fade to new image" then
        slideTransition% = 15
    else if slideTransitionSpec$ = "Slide from top" then
        slideTransition% = 16
    else if slideTransitionSpec$ = "Slide from bottom" then
        slideTransition% = 17
    else if slideTransitionSpec$ = "Slide from left" then
        slideTransition% = 18
    else if slideTransitionSpec$ = "Slide from right" then
        slideTransition% = 19
    endif
    
    return slideTransition%
    
End Function

'endregion

'region BSP Methods
' *************************************************
'
' BSP Methods
'
' *************************************************
Sub InitializeTouchScreen(zone As Object)

    if type(m.touchScreen) <> "roTouchScreen" then
        m.touchScreen = CreateObject("roTouchScreen")
        m.touchScreen.SetPort(m.msgPort)
        REM Puts up a cursor if a mouse is attached
        REM The cursor must be a 32 x 32 BMP
        REM The x,y position is the “hot spot” point
        m.touchScreen.SetCursorBitmap("cursor.bmp", 16, 16)

        videoMode = CreateObject("roVideoMode")
        resX = videoMode.GetResX()
        resY = videoMode.GetResY()
        videoMode = invalid
        
        m.touchScreen.SetResolution(resX, resY)
        m.touchScreen.SetCursorPosition(resX / 2, resY / 2)
    endif

	if type(zone.enabledRegions) <> "roList" then
		zone.enabledRegions = CreateObject("roList")
	endif
	    
End Sub


Sub AddRectangularTouchRegion(zone As Object, touchEvent As Object, eventNum% As Integer)

    x% = touchEvent.x% + zone.x%
    y% = touchEvent.y% + zone.y%
    m.touchScreen.AddRectangleRegion(x%, y%, touchEvent.width%, touchEvent.height%, eventNum%)
    m.touchScreen.EnableRegion(eventNum%, false)

End Sub


Sub SetTouchRegions(state As Object)

	zone = state.stateMachine
	
REM Display the cursor if there is a touch event active in this state
REM If there is only one touch event we assume that it is to exit and don't display the cursor

    if type(m.touchScreen) <> "roTouchScreen" return

    ' clear out all regions in the active zone
    
    if type(zone.enabledRegions) = "roList" then    
		for each eventNum in zone.enabledRegions
			m.touchScreen.EnableRegion(eventNum, false)
		next
		zone.enabledRegions.Clear()
	endif

    numTouchRegions% = 0
    if type(state.touchEvents) = "roAssociativeArray" then
        for each eventNum in state.touchEvents
            m.touchScreen.EnableRegion(val(eventNum), true)
            zone.enabledRegions.AddTail(val(eventNum))
            numTouchRegions% = numTouchRegions% + 1
        next
    endif
    
	if state.type$ = "html5" and state.displayCursor then

        m.touchScreen.EnableCursor(true)
        m.diagnostics.PrintDebug("Html5 state - Cursor enabled")

    else if m.sign.touchCursorDisplayMode$ = "auto" then
    
        if numTouchRegions% > 1 then

            m.touchScreen.EnableCursor(true)
            m.diagnostics.PrintDebug("Cursor enabled")
            
        else

            m.touchScreen.EnableCursor(false)
            m.diagnostics.PrintDebug("Cursor disabled")
            
        endif

    else if m.sign.touchCursorDisplayMode$ = "display" and m.sign.numTouchEvents% > 0 then
    
        m.touchScreen.EnableCursor(true)
        m.diagnostics.PrintDebug("Cursor enabled")

    else
    
        m.touchScreen.EnableCursor(false)
        m.diagnostics.PrintDebug("Cursor disabled")

    endif
    
    return
    
End Sub


' call this function to determine whether or not it is suitable to send the current command to a video player
' the heuristics are as follows: if the current zone type is AudioOnly or EnhancedAudio and there are audio items
' in the zone, then don't send the current command to a video player
Function SendCommandToVideo() As Boolean

	if m.type$ = "AudioOnly" or m.type$ = "EnhancedAudio" then
		for each stateName in m.stateTable
			state = m.stateTable[stateName]
			if (state.type$ = "audio") or (state.type$ = "audioIn") or (state.type$ = "playFile" and state.mediaType$ = "audio") or (state.type$ = "mediaList" and state.mediaType$ = "audio") then
				return false
			endif
		next
	endif

	return true

End Function


Sub MapDigitalOutput(player As Object, parameters As Object)

	parameter = parameters["mapping"]
	digitalOutput$ = parameter.GetCurrentParameterValue()

    m.diagnostics.PrintDebug("Map digital output " + digitalOutput$)
    if type(player) <> "roInvalid" then
        player.MapDigitalOutput(int(val(digitalOutput$)))
    endif

End Sub


Sub SetAudioVolumeLimits(audioSettings As Object)

	audioOutput% = audioSettings.audioOutput%
	stereoMapping% = audioSettings.stereoMapping%

	ANALOG_AUDIO = 0
	USB_AUDIO = 1
	DIGITAL_AUDIO_STEREO_PCM = 2
	DIGITAL_AUDIO_RAW_AC3 = 3
	ANALOG_HDMI_RAW_AC3 = 4
	
	if audioOutput% = ANALOG_AUDIO or audioOutput% = ANALOG_HDMI_RAW_AC3 then
		if stereoMapping% = 0 then
			audioSettings.minVolume% = m.sign.audio1MinVolume%
			audioSettings.maxVolume% = m.sign.audio1MaxVolume%
		else if stereoMapping% = 1 then
			audioSettings.minVolume% = m.sign.audio2MinVolume%
			audioSettings.maxVolume% = m.sign.audio2MaxVolume%
		else
			audioSettings.minVolume% = m.sign.audio3MinVolume%
			audioSettings.maxVolume% = m.sign.audio3MaxVolume%
		endif
	else if audioOutput% = USB_AUDIO then
		audioSettings.minVolume% = m.sign.usbMinVolume%
		audioSettings.maxVolume% = m.sign.usbMaxVolume%
	else if audioOutput% = DIGITAL_AUDIO_STEREO_PCM then
		audioSettings.minVolume% = m.sign.hdmiMinVolume%
		audioSettings.maxVolume% = m.sign.hdmiMaxVolume%
	else
		audioSettings.minVolume% = 0
		audioSettings.maxVolume% = 100
	endif
			
End Sub


Sub SetAudioMode1(parameters As Object)

	parameter = parameters["zoneId"]
	zoneId$ = parameter.GetCurrentParameterValue()

	parameter = parameters["mode"]
	mode$ = parameter.GetCurrentParameterValue()

	zone = m.GetZone(zoneId$)
	if type(zone) = "roAssociativeArray" then
		if lcase(mode$) = "passthrough" then
			mode% = 0
		else if lcase(mode$) = "left" then
			mode% = 3
		else if lcase(mode$) = "right" then
			mode% = 4
		else
			mode% = 1
		endif

		if type(zone.videoPlayer) = "roVideoPlayer" then
			zone.videoPlayer.SetAudioMode(mode%)
		endif

		if IsAudioPlayer(zone.audioPlayer) then
			zone.audioPlayer.SetAudioMode(mode%)
		endif
	endif

End Sub


Sub SetAllAudioOutputs(parameters As Object)

	parameter = parameters["zoneId"]
	zoneId$ = parameter.GetCurrentParameterValue()

	parameter = parameters["analog"]
	analog$ = parameter.GetCurrentParameterValue()

	if parameters.DoesExist("analog2") then
		parameter = parameters["analog2"]
		analog2$ = parameter.GetCurrentParameterValue()
	else
		analog2$ = "none"
	endif

	if parameters.DoesExist("analog3") then
		parameter = parameters["analog3"]
		analog3$ = parameter.GetCurrentParameterValue()
	else
		analog3$ = "none"
	endif

	parameter = parameters["hdmi"]
	hdmi$ = parameter.GetCurrentParameterValue()

	parameter = parameters["spdif"]
	spdif$ = parameter.GetCurrentParameterValue()

	if parameters.DoesExist("usb") then
		parameter = parameters["usb"]
		usb$ = parameter.GetCurrentParameterValue()
	else
		usb$ = "none"
	endif

	pcm = CreateObject("roArray", 1, true)
	compressed = CreateObject("roArray", 1, true)
	multichannel = CreateObject("roArray", 1, true)

	analogAudioOutput = CreateObject("roAudioOutput", "Analog:1")
	analog2AudioOutput = CreateObject("roAudioOutput", "Analog:2")
	analog3AudioOutput = CreateObject("roAudioOutput", "Analog:3")
	hdmiAudioOutput = CreateObject("roAudioOutput", "HDMI")
	spdifAudioOutput = CreateObject("roAudioOutput", "SPDIF")
	usbAudioOutput = CreateObject("roAudioOutput", "USB")

	if lcase(analog$) <> "none" and lcase(analog$) <> "multichannel" then
		pcm.push(analogAudioOutput)
	endif

	if lcase(analog2$) = "pcm" then
		pcm.push(analog2AudioOutput)
	endif

	if lcase(analog3$) = "pcm" then
		pcm.push(analog3AudioOutput)
	endif

	if lcase(analog$)="multichannel" then
		multichannel.push(analogAudioOutput)
	else if lcase(analog2$)="multichannel" then
		multichannel.push(analog2AudioOutput)
	else if lcase(analog3$)="multichannel" then
		multichannel.push(analog3AudioOutput)
	endif

	if lcase(hdmi$) = "passthrough" then
		compressed.push(hdmiAudioOutput)
	else if lcase(hdmi$) <> "none" then
		pcm.push(hdmiAudioOutput)
	endif

	if lcase(spdif$) = "passthrough" then
		compressed.push(spdifAudioOutput)
	else if lcase(spdif$) <> "none" then
		pcm.push(spdifAudioOutput)
	endif

	if lcase(usb$) = "pcm" then
		pcm.push(usbAudioOutput)
	else if lcase(usb$) = "multichannel" then
		multichannel.push(usbAudioOutput)
	endif

	if pcm.Count() = 0 then
		noPCMAudioOutput = CreateObject("roAudioOutput", "none")
		pcm.push(noPCMAudioOutput)
	endif

	if compressed.Count() = 0 then
		noCompressedAudioOutput = CreateObject("roAudioOutput", "none")
		compressed.push(noCompressedAudioOutput)
	endif

	if multichannel.Count() = 0 then
		noMultichannelAudioOutput = CreateObject("roAudioOutput", "none")
		multichannel.push(noMultichannelAudioOutput)
	endif

	zone = m.GetZone(zoneId$)
	if type(zone) = "roAssociativeArray" then

		if type(zone.videoPlayer) = "roVideoPlayer" then
			zone.videoPlayer.SetPcmAudioOutputs(pcm)
			zone.videoPlayer.SetCompressedAudioOutputs(compressed)
			zone.videoPlayer.SetMultichannelAudioOutputs(multichannel)
		endif

		if IsAudioPlayer(zone.audioPlayer) then
			zone.audioPlayer.SetPcmAudioOutputs(pcm)
			zone.audioPlayer.SetCompressedAudioOutputs(compressed)
			zone.audioPlayer.SetMultichannelAudioOutputs(multichannel)
		endif

	endif

End Sub


Sub UnmuteAudioConnector(connector$ As String)

	audioOutput = CreateObject("roAudioOutput", connector$)
	if type(audioOutput) = "roAudioOutput" then
		audioOutput.SetMute(false)
	endif

End Sub


Sub UnmuteAllAudio()

	if m.sysInfo.modelSupportsRoAudioOutput then
		m.UnmuteAudioConnector("Analog:1")
		m.UnmuteAudioConnector("Analog:2")
		m.UnmuteAudioConnector("Analog:3")
		m.UnmuteAudioConnector("HDMI")
		m.UnmuteAudioConnector("SPDIF")
'		m.UnmuteAudioConnector("USB")
	endif

End Sub


Sub MuteAudioOutput(muteOn as Boolean, parameters As Object, parameterName$ As String, objectName$ As String)

	if parameters.DoesExist(parameterName$) then
		parameter = parameters[parameterName$]
		mute$ = parameter.GetCurrentParameterValue()
		if lcase(mute$) = "true" then
			audioOutput = CreateObject("roAudioOutput", objectName$)
			audioOutput.SetMute(muteOn)
		endif
	endif

End Sub


Sub MuteAudioOutputs(muteOn as Boolean, parameters As Object)

	m.MuteAudioOutput(muteOn, parameters, "analog", "Analog:1")
	m.MuteAudioOutput(muteOn, parameters, "analog2", "Analog:2")
	m.MuteAudioOutput(muteOn, parameters, "analog3", "Analog:3")
	m.MuteAudioOutput(muteOn, parameters, "hdmi", "HDMI")
	m.MuteAudioOutput(muteOn, parameters, "spdif", "SPDIF")
	m.MuteAudioOutput(muteOn, parameters, "usb", "USB")

End Sub


Sub SetConnectorVolume(parameters As Object)

	parameter = parameters["connector"]
	connector$ = parameter.GetCurrentParameterValue()

	parameter = parameters["volume"]
	volume$ = parameter.GetCurrentParameterValue()
	volume% = int(val(volume$))

	if lcase(connector$) = "analog" then
		audioOutput = CreateObject("roAudioOutput", "Analog:1")
		m.analogVolume% = volume%
	else if lcase(connector$) = "analog2" then
		audioOutput = CreateObject("roAudioOutput", "Analog:2")
		m.analog2Volume% = volume%
	else if lcase(connector$) = "analog3" then
		audioOutput = CreateObject("roAudioOutput", "Analog:3")
		m.analog3Volume% = volume%
	else if lcase(connector$) = "hdmi" then
		audioOutput = CreateObject("roAudioOutput", "HDMI")
		m.hdmiVolume% = volume%
	else if lcase(connector$) = "spdif" then
		audioOutput = CreateObject("roAudioOutput", "SPDIF")
		m.spdifVolume% = volume%
	else if lcase(connector$) = "usb" then
		audioOutput = CreateObject("roAudioOutput", "USB")
		m.usbVolume% = volume%
	endif

	if type(audioOutput) = "roAudioOutput" then
		audioOutput.SetVolume(volume%)
	endif

End Sub


Sub ChangeConnectorVolume(multiplier% As Integer, parameters As Object)

	parameter = parameters["connector"]
	connector$ = parameter.GetCurrentParameterValue()

	parameter = parameters["volume"]
	volumeDelta$ = parameter.GetCurrentParameterValue()
	volumeDelta% = int(val(volumeDelta$)) * multiplier%

	if lcase(connector$) = "analog" then
		m.analogVolume% = ExecuteChangeConnectorVolume("Analog:1", m.analogVolume% + volumeDelta%)
	else if lcase(connector$) = "analog2" then
		m.analog2Volume% = ExecuteChangeConnectorVolume("Analog:2", m.analog2Volume% + volumeDelta%)
	else if lcase(connector$) = "analog3" then
		m.analog3Volume% = ExecuteChangeConnectorVolume("Analog:3", m.analog3Volume% + volumeDelta%)
	else if lcase(connector$) = "hdmi" then
		m.hdmiVolume% = ExecuteChangeConnectorVolume("HDMI", m.hdmiVolume% + volumeDelta%)
	else if lcase(connector$) = "spdif" then
		m.spdifVolume% = ExecuteChangeConnectorVolume("SPDIF", m.spdifVolume% + volumeDelta%)
	endif

End Sub


Function ExecuteChangeConnectorVolume(connector$ As String, newVolume% As Integer) As Integer

	audioOutput = CreateObject("roAudioOutput", connector$)
	if newVolume% > 100 then
		newVolume% = 100
	else if newVolume% < 0
		newVolume% = 0
	endif
	audioOutput.SetVolume(newVolume%)

	return newVolume%

End Function


Sub SetZoneVolume(parameters As Object)

	parameter = parameters["zoneId"]
	zoneId$ = parameter.GetCurrentParameterValue()

	parameter = parameters["volume"]
	volume$ = parameter.GetCurrentParameterValue()
	volume% = int(val(volume$))

	zone = m.GetZone(zoneId$)
	if type(zone) = "roAssociativeArray" then
		if type(zone.videoPlayer) = "roVideoPlayer" then
			zone.videoPlayer.SetVolume(volume%)
		endif
		if IsAudioPlayer(zone.audioPlayer) then
			zone.audioPlayer.SetVolume(volume%)
		endif
	endif

End Sub


Sub ChangeZoneVolume(multiplier% As Integer, parameters As Object)

	parameter = parameters["zoneId"]
	zoneId$ = parameter.GetCurrentParameterValue()

	parameter = parameters["volume"]
	volumeDelta$ = parameter.GetCurrentParameterValue()
	volumeDelta% = int(val(volumeDelta$)) * multiplier%

	zone = m.GetZone(zoneId$)
	if type(zone) = "roAssociativeArray" then

		if type(zone.videoPlayer) = "roVideoPlayer" then
			if multiplier% > 0 then
				minVolume% = 0
				maxVolume% = zone.videoPlayerAudioSettings.maxVolume%
			else
				minVolume% = zone.videoPlayerAudioSettings.minVolume%
				maxVolume% = 100
			endif
		    m.ChangeChannelVolumes(zone.videoPlayer, zone.videoChannelVolumes, 63, volumeDelta%, minVolume%, maxVolume%)
		endif

		if IsAudioPlayer(zone.audioPlayer) then
			if multiplier% > 0 then
				minVolume% = 0
				maxVolume% = zone.audioPlayerAudioSettings.maxVolume%
			else
				minVolume% = zone.audioPlayerAudioSettings.minVolume%
				maxVolume% = 100
			endif
		    m.ChangeChannelVolumes(zone.audioPlayer, zone.audioChannelVolumes, 63, volumeDelta%, minVolume%, maxVolume%)
		endif

	endif

End Sub


Sub SetZoneChannelVolume(parameters As Object)

	parameter = parameters["zoneId"]
	zoneId$ = parameter.GetCurrentParameterValue()

	parameter = parameters["channel"]
	channelMask$ = parameter.GetCurrentParameterValue()

	parameter = parameters["volume"]
	volume$ = parameter.GetCurrentParameterValue()
	volume% = int(val(volume$))

	zone = m.GetZone(zoneId$)
	if type(zone) = "roAssociativeArray" then

		if type(zone.videoPlayer) = "roVideoPlayer" then
			player = zone.videoPlayer
			channelVolumes = zone.videoChannelVolumes
		else if IsAudioPlayer(zone.audioPlayer) then
			player = zone.audioPlayer
			channelVolumes = zone.audioChannelVolumes
		endif

		m.SetChannelVolumes(player, channelVolumes, int(val(channelMask$)), int(val(volume$)))
	endif

End Sub


Sub ChangeZoneChannelVolume(multiplier% As Integer, parameters As Object)
	
	parameter = parameters["zoneId"]
	zoneId$ = parameter.GetCurrentParameterValue()

	parameter = parameters["channel"]
	channelMask$ = parameter.GetCurrentParameterValue()

	parameter = parameters["volume"]
	volumeDelta$ = parameter.GetCurrentParameterValue()
	volumeDelta% = int(val(volumeDelta$)) * multiplier%

	zone = m.GetZone(zoneId$)
	if type(zone) = "roAssociativeArray" then

		if type(zone.videoPlayer) = "roVideoPlayer" then
			player = zone.videoPlayer
			channelVolumes = zone.videoChannelVolumes
			minVolume% = zone.videoPlayerAudioSettings.minVolume%
			maxVolume% = zone.videoPlayerAudioSettings.maxVolume%
		else if IsAudioPlayer(zone.audioPlayer) then
			player = zone.audioPlayer
			channelVolumes = zone.audioChannelVolumes
			minVolume% = zone.audioPlayerAudioSettings.minVolume%
			maxVolume% = zone.audioPlayerAudioSettings.maxVolume%
		endif

		m.ChangeChannelVolumes(player, channelVolumes, int(val(channelMask$)), volumeDelta%, minVolume%, maxVolume%)

	endif

End Sub


Sub SetAudioOutput(zone As Object, useVideoPlayer As Boolean, parameters As Object)

	parameter = parameters["output"]
	audioOutput$ = parameter.GetCurrentParameterValue()

    m.diagnostics.PrintDebug("Set audio output " + audioOutput$)
    audioOutput% = int(val(audioOutput$))
    
	player = invalid

    if useVideoPlayer then
		zone = m.GetVideoZone(zone)
		if type(zone) = "roAssociativeArray" then
			player = zone.videoPlayer
			zone.videoPlayerAudioSettings.audioOutput% = audioOutput%
			if audioOutput% <> 0 then
				zone.videoPlayerAudioSettings.audioMappingSpan% = 1
			endif
			m.SetAudioVolumeLimits(zone.videoPlayerAudioSettings) 
		endif
	else if IsAudioPlayer(zone.audioPlayer) then
		player = zone.audioPlayer
		zone.audioPlayerAudioSettings.audioOutput% = audioOutput%
		if audioOutput% <> 0 then
			zone.audioPlayerAudioSettings.audioMappingSpan% = 1
		endif
		m.SetAudioVolumeLimits(zone.audioPlayerAudioSettings) 
	endif
	
    if type(player) = "roVideoPlayer" or IsAudioPlayer(player) then
        player.SetAudioOutput(int(val(audioOutput$)))
    endif

End Sub


Sub SetAudioMode(player As Object, parameters As Object)

	parameter = parameters["mode"]
	audioMode$ = parameter.GetCurrentParameterValue()

    if audioMode$ <> "" then
        m.diagnostics.PrintDebug("Set audio mode " + audioMode$)
        if type(player) <> "roInvalid" then
            player.SetAudioMode(int(val(audioMode$)))
        endif
    endif
        
End Sub


Sub MapStereoOutput(zone As Object, useVideoPlayer As Boolean, parameters As Object)  

	parameter = parameters["mapping"]
	mapping$ = parameter.GetCurrentParameterValue()
    
    m.diagnostics.PrintDebug("Map stereo output " + mapping$)
    
    mapping% = 0
    spanning% = 1
    if mapping$ = "onboard-audio2" then
        mapping% = 1
    else if mapping$ = "onboard-audio3" then
        mapping% = 2
    else if mapping$ = "onboard-audio-all" then
		spanning% = 3
    endif
    
'        if m.sysInfo.expanderPresent then
'            mapping% = mapping% + 3
'        endif

	player = invalid

    if useVideoPlayer then
		zone = m.GetVideoZone(zone)
		if type(zone) = "roAssociativeArray" then
			player = zone.videoPlayer
			zone.videoPlayerAudioSettings.stereoMapping% = mapping%
			zone.videoPlayerAudioSettings.audioMappingSpan% = spanning%
			m.SetAudioVolumeLimits(zone.videoPlayerAudioSettings) 
		endif
	else if IsAudioPlayer(zone.audioPlayer) then
		player = zone.audioPlayer
		zone.audioPlayerAudioSettings.stereoMapping% = mapping%
		zone.audioPlayerAudioSettings.audioMappingSpan% = spanning%
		m.SetAudioVolumeLimits(zone.audioPlayerAudioSettings) 
	endif

    if type(player) = "roVideoPlayer" or IsAudioPlayer(player) then
        player.MapStereoOutput(mapping%)
        player.SetStereoMappingSpan(spanning%)
    endif

End Sub


Sub SetSpdifMute(player As Object, parameters As Object)  

	parameter = parameters["mute"]
	muteOn$ = parameter.GetCurrentParameterValue()
    
    m.diagnostics.PrintDebug("Set SPDIF Mute " + muteOn$)
    if type(player) <> "roInvalid" then
        player.SetSpdifMute(int(val(muteOn$)))
    endif

End Sub


Sub SetAnalogMute(channelVolumes As Object, player As Object, parameters As Object)  
    
	parameter = parameters["mute"]
	muteOn$ = parameter.GetCurrentParameterValue()
    
    m.diagnostics.PrintDebug("Set Analog Mute " + muteOn$)
    if type(player) <> "roInvalid" and type(channelVolumes) = "roArray" then
        muteOn% = int(val(muteOn$))
        if muteOn% = 0 then
            for i% = 0 to 5
                mask% = 2 ^ i%
                player.SetChannelVolumes(mask%, channelVolumes[i%])
            next
        else
            player.SetChannelVolumes(63, 0)
        endif
    endif

End Sub


Sub SetHDMIMute(parameters As Object)

	parameter = parameters["mute"]
	muteOn$ = parameter.GetCurrentParameterValue()
    
    m.diagnostics.PrintDebug("Set HDMI Mute " + muteOn$)

    videoMode = CreateObject("roVideoMode")

	if muteOn$ = "1" then
		disableHDMIAudio = true
	else
		disableHDMIAudio = false
	endif
	
    videoMode.HdmiAudioDisable(disableHDMIAudio)
    videoMode = invalid

End Sub


Sub SetVideoVolume(zone As Object, parameter$ As String)

    volume% = int(val(parameter$))
    
	zone = m.GetVideoZone(zone)
    if type(zone) = "roAssociativeArray" then
        zone.videoPlayer.SetVolume(volume%)
        for i% = 0 to 5
            zone.videoChannelVolumes[i%] = volume%
        next
    endif

End Sub


Sub SetVideoVolumeByConnector(zone As Object, output$ As String, volume$ As String)

	volume% = int(val(volume$))

	zone = m.GetVideoZone(zone)
    if type(zone) = "roAssociativeArray" then
		if zone.videoPlayerAudioSettings.audioMappingSpan% = 3 then
			if output$ = "onboard-audio1" then
				channelMask% = 3
				zone.videoChannelVolumes[0] = volume%
				zone.videoChannelVolumes[1] = volume%
			else if output$ = "onboard-audio2" then
				channelMask% = 12
				zone.videoChannelVolumes[2] = volume%
				zone.videoChannelVolumes[3] = volume%
			else if output$ = "onboard-audio3" then
				channelMask% = 48
				zone.videoChannelVolumes[4] = volume%
				zone.videoChannelVolumes[5] = volume%
			else
				channelMask% = 63
				for i% = 0 to 5
					zone.videoChannelVolumes[i%] = volume%
				next
			endif
		else
			channelMask% = 63
			for i% = 0 to 5
				zone.videoChannelVolumes[i%] = volume%
			next
		endif
        
'			if analogOutput$ = "onboard-audio1" then
'				channelMask% = 3
'				zone.videoChannelVolumes[0] = volume%
'				zone.videoChannelVolumes[1] = volume%
'			else if analogOutput$ = "onboard-audio2" then
'				channelMask% = 12
'				zone.videoChannelVolumes[2] = volume%
'				zone.videoChannelVolumes[3] = volume%
'			else if analogOutput$ = "onboard-audio3" then
'				channelMask% = 48
'				zone.videoChannelVolumes[4] = volume%
'				zone.videoChannelVolumes[5] = volume%
'			else
'				channelMask% = 63
'				for i% = 0 to 5
'					zone.videoChannelVolumes[i%] = volume%
'				next
'			endif

        zone.videoPlayer.SetChannelVolumes(channelMask%, volume%)
    endif

End Sub


Sub SetVideoChannnelVolume(zone As Object, channelMask$ As String, volume$ As String)
    
	zone = m.GetVideoZone(zone)
    if type(zone) = "roAssociativeArray" then
	    m.SetChannelVolumes(zone.videoPlayer, zone.videoChannelVolumes, int(val(channelMask$)), int(val(volume$)))
    endif
    
End Sub


Sub IncrementVideoChannnelVolumes(zone As Object, channelMask$ As String, volumeDelta$ As String)

	zone = m.GetVideoZone(zone)
	if type(zone) = "roAssociativeArray" then
		channelMask% = int(val(channelMask$))
		m.ChangeVideoVolume(zone, channelMask%, int(val(volumeDelta$)), zone.videoPlayerAudioSettings.minVolume%, zone.videoPlayerAudioSettings.maxVolume%)
	endif
    
End Sub


Sub DecrementVideoChannnelVolumes(zone As Object, channelMask$ As String, volumeDelta$ As String)

	zone = m.GetVideoZone(zone)
	if type(zone) = "roAssociativeArray" then
		channelMask% = int(val(channelMask$))
		delta% = int(val(volumeDelta$))
		m.ChangeVideoVolume(zone, channelMask%, -delta%, zone.videoPlayerAudioSettings.minVolume%, zone.videoPlayerAudioSettings.maxVolume%)
	endif

End Sub


Sub SetAudioVolume(zone As Object, parameter$ As String)

    volume% = int(val(parameter$))
    
    if type(zone) = "roAssociativeArray" then
		if IsAudioPlayer(zone.audioPlayer) then
            zone.audioPlayer.SetVolume(volume%)
            for i% = 0 to 5
                zone.audioChannelVolumes[i%] = volume%
            next
        endif
    endif

End Sub


Sub SetAudioVolumeByConnector(zone As Object, output$ As String, volume$ As String)
    
    if type(zone) = "roAssociativeArray" then
    
		if IsAudioPlayer(zone.audioPlayer) then
        
			volume% = int(val(volume$))

			if zone.audioPlayerAudioSettings.audioMappingSpan% = 3 then
				if output$ = "onboard-audio1" then
					channelMask% = 3
					zone.audioChannelVolumes[0] = volume%
					zone.audioChannelVolumes[1] = volume%
				else if output$ = "onboard-audio2" then
					channelMask% = 12
					zone.audioChannelVolumes[2] = volume%
					zone.audioChannelVolumes[3] = volume%
				else if output$ = "onboard-audio3" then
					channelMask% = 48
					zone.audioChannelVolumes[4] = volume%
					zone.audioChannelVolumes[5] = volume%
				else
					channelMask% = 63
					for i% = 0 to 5
						zone.audioChannelVolumes[i%] = volume%
					next
				endif
			else
				channelMask% = 63
				for i% = 0 to 5
					zone.audioChannelVolumes[i%] = volume%
				next
			endif

'			if analogOutput$ = "onboard-audio1" then
'				channelMask% = 3
'				zone.audioChannelVolumes[0] = volume%
'				zone.audioChannelVolumes[1] = volume%
'			else if analogOutput$ = "onboard-audio2" then
'				channelMask% = 12
'				zone.audioChannelVolumes[2] = volume%
'				zone.audioChannelVolumes[3] = volume%
'			else if analogOutput$ = "onboard-audio3" then
'				channelMask% = 48
'				zone.audioChannelVolumes[4] = volume%
'				zone.audioChannelVolumes[5] = volume%
'			else
'				channelMask% = 63
'				for i% = 0 to 5
'					zone.audioChannelVolumes[i%] = volume%
'				next
'			endif

            zone.audioPlayer.SetChannelVolumes(channelMask%, volume% )
	
        endif
        
    endif

End Sub


Sub SetAudioChannnelVolume(zone As Object, channelMask$ As String, volume$ As String)
    
    if type(zone) = "roAssociativeArray" then
		if IsAudioPlayer(zone.audioPlayer) then
            m.SetChannelVolumes(zone.audioPlayer, zone.audioChannelVolumes, int(val(channelMask$)), int(val(volume$)))
        endif
    endif
    
End Sub


Sub IncrementAudioVolume(zone As Object, parameter$ As String, maxVolume% As Integer)

    m.ChangeAudioVolume(zone, 63, int(val(parameter$)), 0, maxVolume%)        

End Sub


Sub DecrementAudioVolume(zone As Object, parameter$ As String, minVolume% As Integer)

    delta% = int(val(parameter$))
    m.ChangeAudioVolume(zone, 63, -delta%, minVolume%, 100)        

End Sub


Sub SetChannelVolumes(player As Object, channelVolumes As Object, channelMask% As Integer, volume% As Integer)

    for i% = 0 to 5
        mask% = 2 ^ i%
        if channelMask% and mask% then
            channelVolumes[i%] = volume%
            player.SetChannelVolumes(mask%, channelVolumes[i%])
' print "SetChannelVolumes - mask = ";mask%;", volume = ";channelVolumes[i%]                  
        endif
    next
            
End Sub


Function GetVideoZone(zone As Object) As Object

	if type(zone) = "roAssociativeArray" then
		if type(zone.videoPlayer) = "roVideoPlayer" then
			return zone
		endif
	endif

    if type(m.sign) = "roAssociativeArray" then
        if type(m.sign.videoZoneHSM) = "roAssociativeArray" and type(m.sign.videoZoneHSM.videoPlayer) = "roVideoPlayer" then
            return m.sign.videoZoneHSM
        endif
    endif

	return invalid

End Function


Function GetZone(zoneId$ As String) As Object

	for each zone in m.sign.zonesHSM
		if zone.id$ = zoneId$ then
			return zone
		endif
	next

	return invalid

End Function


Sub ChangeChannelVolumes(player As Object, channelVolumes As Object, channelMask% As Integer, delta% As Integer, minVolume% As Integer, maxVolume% As Integer)

    for i% = 0 to 5
        mask% = 2 ^ i%
        if channelMask% and mask% then
            channelVolumes[i%] = channelVolumes[i%] + delta%
            if channelVolumes[i%] > maxVolume% then
                channelVolumes[i%] = maxVolume%
            else if channelVolumes[i%] < minVolume% then
                channelVolumes[i%] = minVolume%
            endif
            player.SetChannelVolumes(mask%, channelVolumes[i%])
' print "SetChannelVolumes - mask = ";mask%;", volume = ";channelVolumes[i%]                  
        endif
    next
            
End Sub


Sub ChangeVideoVolumeByConnector(zone As Object, output$ As String, volumeDelta% As Integer)
    
    if type(zone) = "roAssociativeArray" then
    		
		if zone.videoPlayerAudioSettings.audioMappingSpan% = 3 then
			if output$ = "onboard-audio1" then
				m.ChangeChannelVolumes(zone.videoPlayer, zone.videoChannelVolumes, 3, volumeDelta%, m.sign.audio1MinVolume%, m.sign.audio1MaxVolume%)
			else if output$ = "onboard-audio2" then
				m.ChangeChannelVolumes(zone.videoPlayer, zone.videoChannelVolumes, 12, volumeDelta%, m.sign.audio2MinVolume%, m.sign.audio2MaxVolume%)
			else if output$ = "onboard-audio3" then
				m.ChangeChannelVolumes(zone.videoPlayer, zone.videoChannelVolumes, 48, volumeDelta%, m.sign.audio3MinVolume%, m.sign.audio3MaxVolume%)
			else
				m.ChangeChannelVolumes(zone.videoPlayer, zone.videoChannelVolumes, 3, volumeDelta%, m.sign.audio1MinVolume%, m.sign.audio1MaxVolume%)
				m.ChangeChannelVolumes(zone.videoPlayer, zone.videoChannelVolumes, 12, volumeDelta%, m.sign.audio2MinVolume%, m.sign.audio2MaxVolume%)
				m.ChangeChannelVolumes(zone.videoPlayer, zone.videoChannelVolumes, 48, volumeDelta%, m.sign.audio3MinVolume%, m.sign.audio3MaxVolume%)
			endif
'			else if zone.videoPlayerAudioSettings.audioOutput% = 0 then
'	            m.ChangeChannelVolumes(zone.videoPlayer, zone.videoChannelVolumes, 3, volumeDelta%, m.sign.audio1MinVolume%, m.sign.audio1MaxVolume%)
'	            m.ChangeChannelVolumes(zone.videoPlayer, zone.videoChannelVolumes, 12, volumeDelta%, m.sign.audio2MinVolume%, m.sign.audio2MaxVolume%)
'	            m.ChangeChannelVolumes(zone.videoPlayer, zone.videoChannelVolumes, 48, volumeDelta%, m.sign.audio3MinVolume%, m.sign.audio3MaxVolume%)
		else
	        m.ChangeChannelVolumes(zone.videoPlayer, zone.videoChannelVolumes, 63, volumeDelta%, zone.videoPlayerAudioSettings.minVolume%, zone.videoPlayerAudioSettings.maxVolume%)
		endif
    
    endif

End Sub


Sub IncrementVideoVolumeByConnector(zone As Object, output$ As String, volumeDelta$ As String)

	zone = m.GetVideoZone(zone)
    delta% = int(val(volumeDelta$))
	m.ChangeVideoVolumeByConnector(zone, output$, delta%)

End Sub


Sub DecrementVideoVolumeByConnector(zone As Object, output$ As String, volumeDelta$ As String)

	zone = m.GetVideoZone(zone)
    delta% = int(val(volumeDelta$))
	m.ChangeVideoVolumeByConnector(zone, output$, -delta%)
	
End Sub


Sub ChangeVideoVolume(zone As Object, channelMask% as Integer, delta% As Integer, minVolume% As Integer, maxVolume% As Integer)

    m.ChangeChannelVolumes(zone.videoPlayer, zone.videoChannelVolumes, channelMask%, delta%, minVolume%, maxVolume%)
    
End Sub


Sub IncrementVideoVolume(zone As Object, volumeDelta$ As String)

	zone = m.GetVideoZone(zone)

	if type(zone) = "roAssociativeArray" then
	    m.ChangeVideoVolume(zone, 63, int(val(volumeDelta$)), 0, zone.videoPlayerAudioSettings.maxVolume%)        
	endif

End Sub


Sub DecrementVideoVolume(zone As Object, volumeDelta$ As String)

	zone = m.GetVideoZone(zone)

	if type(zone) = "roAssociativeArray" then
	    delta% = int(val(volumeDelta$))
	    m.ChangeVideoVolume(zone, 63, -delta%, zone.videoPlayerAudioSettings.minVolume%, 100)
	endif

End Sub


Sub ChangeAudioVolumeByConnector(zone As Object, output$ As String, volumeDelta% As Integer)
    
    if type(zone) = "roAssociativeArray" then
    
		if IsAudioPlayer(zone.audioPlayer) then
		
			if zone.audioPlayerAudioSettings.audioMappingSpan% = 3 then
				if output$ = "onboard-audio1" then
					m.ChangeChannelVolumes(zone.audioPlayer, zone.audioChannelVolumes, 3, volumeDelta%, m.sign.audio1MinVolume%, m.sign.audio1MaxVolume%)
				else if output$ = "onboard-audio2" then
					m.ChangeChannelVolumes(zone.audioPlayer, zone.audioChannelVolumes, 12, volumeDelta%, m.sign.audio2MinVolume%, m.sign.audio2MaxVolume%)
				else if output$ = "onboard-audio3" then
					m.ChangeChannelVolumes(zone.audioPlayer, zone.audioChannelVolumes, 48, volumeDelta%, m.sign.audio3MinVolume%, m.sign.audio3MaxVolume%)
				else
					m.ChangeChannelVolumes(zone.audioPlayer, zone.audioChannelVolumes, 3, volumeDelta%, m.sign.audio1MinVolume%, m.sign.audio1MaxVolume%)
					m.ChangeChannelVolumes(zone.audioPlayer, zone.audioChannelVolumes, 12, volumeDelta%, m.sign.audio2MinVolume%, m.sign.audio2MaxVolume%)
					m.ChangeChannelVolumes(zone.audioPlayer, zone.audioChannelVolumes, 48, volumeDelta%, m.sign.audio3MinVolume%, m.sign.audio3MaxVolume%)
				endif
'			else if zone.audioPlayerAudioSettings.audioOutput% = 0 then
'	            m.ChangeChannelVolumes(zone.audioPlayer, zone.audioChannelVolumes, 3, volumeDelta%, m.sign.audio1MinVolume%, m.sign.audio1MaxVolume%)
'	            m.ChangeChannelVolumes(zone.audioPlayer, zone.audioChannelVolumes, 12, volumeDelta%, m.sign.audio2MinVolume%, m.sign.audio2MaxVolume%)
'	            m.ChangeChannelVolumes(zone.audioPlayer, zone.audioChannelVolumes, 48, volumeDelta%, m.sign.audio3MinVolume%, m.sign.audio3MaxVolume%)
			else
	            m.ChangeChannelVolumes(zone.audioPlayer, zone.audioChannelVolumes, 63, volumeDelta%, zone.audioPlayerAudioSettings.minVolume%, zone.audioPlayerAudioSettings.maxVolume%)
			endif
        endif
    
    endif

End Sub


Sub IncrementAudioVolumeByConnector(zone As Object, output$ As String, volumeDelta$ As String)

	m.ChangeAudioVolumeByConnector(zone, output$, int(val(volumeDelta$)))
	
End Sub


Sub DecrementAudioVolumeByConnector(zone As Object, output$ As String, volumeDelta$ As String)

    delta% = int(val(volumeDelta$))
	m.ChangeAudioVolumeByConnector(zone, output$, -delta%)
	
End Sub


Sub ChangeAudioVolume(zone As Object, channelMask% as Integer, delta% As Integer, minVolume% As Integer, maxVolume% As Integer)

    if type(zone) = "roAssociativeArray" then
		if IsAudioPlayer(zone.audioPlayer) then
            m.ChangeChannelVolumes(zone.audioPlayer, zone.audioChannelVolumes, channelMask%, delta%, minVolume%, maxVolume%)
        endif
    endif
    
End Sub


Sub IncrementAudioChannelVolumes(zone As Object, channelMask$ As String, volumeDelta$ As String)
    
	if IsAudioPlayer(zone.audioPlayer) then
		channelMask% = int(val(channelMask$))
		m.ChangeAudioVolume(zone, channelMask%, int(val(volumeDelta$)), zone.audioPlayerAudioSettings.minVolume%, zone.audioPlayerAudioSettings.maxVolume%)
    endif
    
End Sub


Sub DecrementAudioChannelVolumes(zone As Object, channelMask$ As String, volumeDelta$ As String)

	if IsAudioPlayer(zone.audioPlayer) then
		channelMask% = int(val(channelMask$))
		delta% = int(val(volumeDelta$))
		m.ChangeAudioVolume(zone, channelMask%, -delta%, zone.audioPlayerAudioSettings.minVolume%, zone.audioPlayerAudioSettings.maxVolume%)
    endif

End Sub


Sub ConfigureAudioResources()

	if m.bsp.sysInfo.deviceFamily$ = "panther" or m.bsp.sysInfo.deviceFamily$ = "cheetah" or m.bsp.sysInfo.deviceFamily$ = "puma" then
		if type(m.videoPlayer) = "roVideoPlayer" then
			m.videoPlayer.ConfigureAudioResources()
		else if IsAudioPlayer(m.audioPlayer) then
			m.audioPlayer.ConfigureAudioResources()
		endif
	endif

End Sub


Sub CecDisplayOn()

	m.SendCecCommand("400D")

End Sub


Sub CecDisplayOff()

	m.SendCecCommand("4036")

End Sub


Sub CecPhilipsSetVolume(volume% As Integer)

	b = CreateObject("roByteArray")
	b[0] = volume%
	volumeAsAscii$ = b.ToHexString()
	b = invalid
	setVolume$ = "40A0000C3022" + volumeAsAscii$
	SendCecCommand(setVolume$)
	
End Sub


Sub SendCecCommand(cecCommand$ As String)

	cec = CreateObject("roCecInterface")
	if type(cec) = "roCecInterface" then
		b = CreateObject("roByteArray")
		b.fromhexstring(cecCommand$)
		cec.SendRawMessage(b)
		cec = invalid
	endif
	
End Sub


Sub PauseVideo(zone As Object)

	zone = m.GetVideoZone(zone)
	if type(zone) = "roAssociativeArray" then
        zone.videoPlayer.Pause()
    endif

End Sub


Sub ResumeVideo(zone As Object)

	zone = m.GetVideoZone(zone)
	if type(zone) = "roAssociativeArray" then
        zone.videoPlayer.Resume()
    endif

End Sub


Sub SetPowerSaveMode(enablePowerSaveMode As Boolean)

    videoMode = CreateObject("roVideoMode")
    videoMode.SetPowerSaveMode(enablePowerSaveMode)
    videoMode = invalid

End Sub


Function GetAttachedFiles() As Object

	return m.additionalPublishedFiles

End Function


'endregion

'region Common Zone State Machine Methods
' *************************************************
'
' Common Zone State Machine Methods
'
' *************************************************

Sub newZoneCommon(bsp As Object, zoneXML As Object, zoneHSM As Object)

	zoneHSM.audioPlayer = invalid
	zoneHSM.videoPlayer = invalid

    zoneHSM.name$ = zoneXML.name.GetText()
    zoneHSM.x% = int(val(zoneXML.x.GetText()))
    zoneHSM.y% = int(val(zoneXML.y.GetText()))
    zoneHSM.width% = int(val(zoneXML.width.GetText()))
    zoneHSM.height% = int(val(zoneXML.height.GetText()))
    zoneHSM.type$ = zoneXML.type.GetText()
    zoneHSM.id$ = zoneXML.id.GetText()

    zoneHSM.bsp = bsp

	zoneHSM.ConfigureAudioResources = ConfigureAudioResources
	zoneHSM.SetAudioOutputAndMode = SetAudioOutputAndMode

	zoneHSM.LogPlayStart = LogPlayStart
	zoneHSM.ClearImagePlane = ClearImagePlane
	zoneHSM.ShowImageWidget = ShowImageWidget
	zoneHSM.ShowCanvasWidget = ShowCanvasWidget
	zoneHSM.ShowHtmlWidget = ShowHtmlWidget
	zoneHSM.UpdateWidgetVisibility = UpdateWidgetVisibility

	zoneHSM.SendCommandToVideo = SendCommandToVideo

    zoneHSM.stTop = zoneHSM.newHState(bsp, "Top")
    zoneHSM.stTop.HStateEventHandler = STTopEventHandler
    
	zoneHSM.topState = zoneHSM.stTop

End Sub


Sub InitializeZoneCommon(msgPort As Object)

    zoneHSM = m

    zoneHSM.msgPort = msgPort
    
    zoneHSM.isVideoZone = false
    zoneHSM.preloadState = invalid
    zoneHSM.preloadedStateName$ = ""
    
    zoneHSM.rectangle = CreateObject("roRectangle", zoneHSM.x%, zoneHSM.y%, zoneHSM.width%, zoneHSM.height%)

    ' byte arrays to store stream byte input
    zoneHSM.serialStreamInputBuffers = CreateObject("roArray", 6, true)
    for i% = 0 to 5
		zoneHSM.serialStreamInputBuffers[i%] = CreateObject("roByteArray")
	next
    
End Sub

'endregion

'region MediaItem Methods
' *************************************************
'
' MediaItem Methods
'
' *************************************************

Function GetNextStateName(transition As Object) As Object

	nextState = { }

	if type(transition.conditionalTargets) = "roArray" then
		for each conditionalTarget in transition.conditionalTargets

			matchFound = false

			currentValue% = val(conditionalTarget.userVariable.GetCurrentValue())
			userVariableValue% = val(conditionalTarget.userVariableValue$)

			if conditionalTarget.operator$ = "EQ" then
				if conditionalTarget.userVariable.GetCurrentValue() = conditionalTarget.userVariableValue$ then
					matchFound = true
				endif
			else if conditionalTarget.operator$ = "LT" then
				if currentValue% < userVariableValue% then
					matchFound = true
				endif
			else if conditionalTarget.operator$ = "LTE" then
				if currentValue% <= userVariableValue% then
					matchFound = true
				endif
			else if conditionalTarget.operator$ = "GT" then
				if currentValue% > userVariableValue% then
					matchFound = true
				endif
			else if conditionalTarget.operator$ = "GTE" then
				if currentValue% >= userVariableValue% then
					matchFound = true
				endif
			else if conditionalTarget.operator$ = "B" then
				userVariableValue2% = val(conditionalTarget.userVariableValue2$)
				if currentValue% >= userVariableValue% and currentValue% <= userVariableValue2% then
					matchFound = true
				endif
			endif

			if matchFound then
				if conditionalTarget.targetMediaStateIsPreviousState then
					nextState$ = m.stateMachine.previousStateName$
				else
					nextState$ = conditionalTarget.targetMediaState$
				endif

				nextState.nextState$ = nextState$
				nextState.actualTarget = conditionalTarget
				return nextState
			endif

		next
	endif

    if transition.targetMediaStateIsPreviousState then
        nextState$ = m.stateMachine.previousStateName$
    else
        nextState$ = transition.targetMediaState$
    endif

	nextState.nextState$ = nextState$
	nextState.actualTarget = transition
    return nextState
    
End Function


Sub UpdatePreviousCurrentStateNames()

	m.stateMachine.previousStateName$ = m.id$

End Sub


Function GetAnyMediaRSSTransition() As Object

	transition = invalid

	' support others?

	if type(m.signChannelEndEvent) = "roAssociativeArray" then
		transition = m.signChannelEndEvent
	else if type(m.mstimeoutEvent) = "roAssociativeArray" then
		transition = m.mstimeoutEvent
	endif

	return transition

End Function


Function ExecuteTransition(transition As Object, stateData As Object, payload$ As String) As String

	nextState$ = "init"

	while nextState$ <> ""

		' before transitioning to next state, ensure that the transition is allowed
		nextState = m.GetNextStateName(transition)
		nextState$ = nextState.nextState$
		actualTarget = nextState.actualTarget

		if nextState$ <> "" then

			nextState = m.stateMachine.stateTable[nextState$]

			if nextState.type$ = "mediaRSS" and nextState.rssURL$ = "" then
				' skip an empty localized playlist
				m.bsp.diagnostics.PrintDebug("Unassigned local playlist " + nextState.name$ + " encountered, attempt to navigate to next state.")
				m.bsp.logging.WriteDiagnosticLogEntry(m.bsp.diagnosticCodes.EVENT_UNASSIGNED_LOCAL_PLAYLIST, nextState.name$)
				
				defaultTransition = nextState.GetAnyMediaRSSTransition()
				if defaultTransition <> invalid then
					transition = defaultTransition
				else
					' no transition found - not sure what to do
					m.bsp.diagnostics.PrintDebug("Unable to navigate from unassigned local playlist " + nextState.name$)
					m.bsp.logging.WriteDiagnosticLogEntry(m.bsp.diagnosticCodes.EVENT_UNASSIGNED_LOCAL_PLAYLIST_NO_NAVIGATION, nextState.name$)
					exit while
				endif
			
			else

				if nextState.type$ = "playFile" then
					if not nextState.filesTable.DoesExist(payload$) then
						m.bsp.diagnostics.PrintDebug("transition cancelled - payload " + payload$ + " not found in target state's table")
						return "HANDLED"
					else
						' set payload$ member before ExecuteTransitionCommands is called - needed if there is a synchronize transition command
						nextState.payload$ = payload$
					endif
				endif

				exit while

			endif

		endif

	end while

	switchToNewPresentation = m.bsp.ExecuteTransitionCommands(m.stateMachine, actualTarget)
	
	if switchToNewPresentation then
		return "HANDLED"
	endif

	if nextState$ = "" then
		return "HANDLED"
	else
	    stateData.nextState = m.stateMachine.stateTable[nextState$]
		stateData.nextState.payload$ = payload$

		m.UpdatePreviousCurrentStateNames()

	    return "TRANSITION"
	endif

End Function


Sub AssignEventInputToUserVariable(bsp As Object, input$ As String)

	if type(m.variableToAssign) = "roAssociativeArray" then
		
		m.variableToAssign.SetCurrentValue(input$, true)

	else

		userVariablesUpdated = false

		regex = CreateObject("roRegEx", "!!", "i")
		variableAssignments = regex.Split(input$)
		if variableAssignments.Count() > 0 then
			for each variableAssignment in variableAssignments
				regex = CreateObject("roRegEx",":","i")
				parts = regex.Split(variableAssignment)
				if parts.Count() = 2 then
					variableToAssign$ = parts[0]
					newValue$ = parts[1]
					variableToAssign = bsp.GetUserVariable(variableToAssign$)
					if variableToAssign = invalid then
						bsp.diagnostics.PrintDebug("User variable " + variableToAssign$ + " not found.")
					else
						variableToAssign.SetCurrentValue(newValue$, false)
						userVariablesUpdated = true
					endif
				endif
			next
		endif

		if userVariablesUpdated then
			userVariablesChanged = CreateObject("roAssociativeArray")
			userVariablesChanged["EventType"] = "USER_VARIABLES_UPDATED"
			bsp.msgPort.PostMessage(userVariablesChanged)
		endif

	endif

End Sub


Function MediaItemEventHandler(event As Object, stateData As Object) As Object

    if type(event) = "roControlDown" and stri(event.GetSourceIdentity()) = stri(m.bsp.controlPort.GetIdentity()) then
        m.bsp.diagnostics.PrintDebug("Control Down" + str(event.GetInt()))
        gpioNum$ = StripLeadingSpaces(str(event.GetInt()))
        gpioEvents = m.gpioEvents
        if type(gpioEvents[gpioNum$]) = "roAssociativeArray" then
			m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "gpioButton", gpioNum$, "1")
			return m.ExecuteTransition(gpioEvents[gpioNum$], stateData, "")
        else

			if type(m.auxDisconnectEvents) = "roAssociativeArray" then
				if gpioNum$ = "31" then
					if type(m.auxDisconnectEvents["BrightSignAuxIn"]) = "roAssociativeArray" then
						m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "auxDisconnect", gpioNum$, "1")
						return m.ExecuteTransition(m.auxDisconnectEvents["BrightSignAuxIn"], stateData, "")
					endif
				endif
			endif

			' WHISKERS
			if type(m.auxConnectEvents) = "roAssociativeArray" then
				if gpioNum$ = "3" then
					if type(m.auxConnectEvents["Aux300Audio1"]) = "roAssociativeArray" then
						m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "auxConnect", gpioNum$, "1")
						return m.ExecuteTransition(m.auxConnectEvents["Aux300Audio1"], stateData, "")
					endif
				else if gpioNum$ = "4" then
					if type(m.auxConnectEvents["Aux300Audio2"]) = "roAssociativeArray" then
						m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "auxConnect", gpioNum$, "1")
						return m.ExecuteTransition(m.auxConnectEvents["Aux300Audio2"], stateData, "")
					endif
				else if gpioNum$ = "5" then
					if type(m.auxConnectEvents["Aux300Audio3"]) = "roAssociativeArray" then
						m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "auxConnect", gpioNum$, "1")
						return m.ExecuteTransition(m.auxConnectEvents["Aux300Audio3"], stateData, "")
					endif
				endif
			endif

			m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "gpioButton", gpioNum$, "0")
		endif 

	else if type(event) = "roControlUp" and stri(event.GetSourceIdentity()) = stri(m.bsp.controlPort.GetIdentity()) then
        m.bsp.diagnostics.PrintDebug("Control Up" + str(event.GetInt()))
        gpioNum$ = StripLeadingSpaces(str(event.GetInt()))

		if type(m.auxConnectEvents) = "roAssociativeArray" then
			if gpioNum$ = "31" then
				if type(m.auxConnectEvents["BrightSignAuxIn"]) = "roAssociativeArray" then
					m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "auxConnect", gpioNum$, "1")
					return m.ExecuteTransition(m.auxConnectEvents["BrightSignAuxIn"], stateData, "")
				endif
			endif
		endif

		' WHISKERS
		if type(m.auxDisconnectEvents) = "roAssociativeArray" then
			if gpioNum$ = "3" then
				if type(m.auxDisconnectEvents["Aux300Audio1"]) = "roAssociativeArray" then
					m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "auxDisconnect", gpioNum$, "1")
					return m.ExecuteTransition(m.auxDisconnectEvents["Aux300Audio1"], stateData, "")
				endif
			else if gpioNum$ = "4" then
				if type(m.auxDisconnectEvents["Aux300Audio2"]) = "roAssociativeArray" then
					m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "auxDisconnect", gpioNum$, "1")
					return m.ExecuteTransition(m.auxDisconnectEvents["Aux300Audio2"], stateData, "")
				endif
			else if gpioNum$ = "5" then
				if type(m.auxDisconnectEvents["Aux300Audio3"]) = "roAssociativeArray" then
					m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "auxDisconnect", gpioNum$, "1")
					return m.ExecuteTransition(m.auxDisconnectEvents["Aux300Audio3"], stateData, "")
				endif
			endif
		endif

    else if type(event) = "roTimerEvent" then
        
		if type(m.mstimeoutEvent) = "roAssociativeArray" then
            if type(m.mstimeoutTimer) = "roTimer" then
                if stri(event.GetSourceIdentity()) = stri(m.mstimeoutTimer.GetIdentity()) then
					m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "timer", "", "1")
					return m.ExecuteTransition(m.mstimeoutEvent, stateData, "")
                endif
            endif
        endif

		if type(m.timeClockEvents) = "roArray" then
			for each timeClockEvent in m.timeClockEvents
				if type(timeClockEvent.timer) = "roTimer" then
	                if stri(event.GetSourceIdentity()) = stri(timeClockEvent.timer.GetIdentity()) then
						systemTime = CreateObject("roSystemTime")
						currentDateTime = systemTime.GetLocalDateTime()

						' daily timer
						if type(timeClockEvent.timeClockDaily%) = "roInt" then

							triggerEvent = EventActiveToday(currentDateTime, timeClockEvent.daysOfWeek%)

							' restart timer
							LaunchTimeClockEventTimer(m, timeClockEvent)

							if not triggerEvent then
								m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "timeClock", "", "0")
								return "HANDLED"
							endif

						' periodic timer
						else if type(timeClockEvent.timeClockPeriodicInterval%) = "roInt" then

							' units in seconds rather than minutes?
							currentTime% = currentDateTime.GetHour() * 60 + currentDateTime.GetMinute()
							startTime% = timeClockEvent.timeClockPeriodicStartTime%
							endTime% = timeClockEvent.timeClockPeriodicEndTime%
							intervalTime% = timeClockEvent.timeClockPeriodicInterval%

							triggerEvent = false
							withinWindow = TimeWithinWindow(currentTime%, startTime%, endTime%)
							if withinWindow then
								triggerEvent = EventActiveToday(currentDateTime, timeClockEvent.daysOfWeek%)
							endif

							' restart timer
							LaunchTimeClockEventTimer(m, timeClockEvent)

							if not triggerEvent then
								m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "timeClock", "", "0")
								return "HANDLED"
							endif
						endif

						m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "timeClock", "", "1")
						return m.ExecuteTransition(timeClockEvent.transition, stateData, "")

					endif
				endif
			next
		endif

		if type(m.bsp.mediaListInactivity) = "roAssociativeArray" then
			if type(m.bsp.mediaListInactivity.timer) = "roTimer" then
				if stri(event.GetSourceIdentity()) = stri(m.bsp.mediaListInactivity.timer.GetIdentity()) then
					' reset indices for all media lists
					if type(m.bsp.mediaListInactivity.mediaListStates) = "roList" then
						m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "mediaListInactivityTimer", "", "1")
						for each mediaListState in m.bsp.mediaListInactivity.mediaListStates
							mediaListState.playbackIndex% = 0
						next
					else
						m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "mediaListInactivityTimer", "", "0")
					endif
					return "HANDLED"
				endif
			endif
		endif

		m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "timer", "", "0")

    else if type(event) = "roTouchEvent" then
		touchIndex$ = str(event.GetInt())
		m.bsp.diagnostics.PrintDebug("Touch event" + touchIndex$)
        if type(m.touchEvents) = "roAssociativeArray" then
			touchEvent = m.touchEvents[touchIndex$]
            if type(touchEvent) = "roAssociativeArray" then
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "touch", touchIndex$, "1")
				return m.ExecuteTransition(touchEvent, stateData, "")
            endif
        endif
		m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "touch", touchIndex$, "0")
    else if type(event) = "roStreamLineEvent" then
        
        serialEvent$ = event.GetString()
        port$ = event.GetUserData()
		port% = int(val(port$))

		if m.bsp.gpsConfigured and m.bsp.sign.serialPortConfigurations[port%].gps then

			gpsData = ParseGPSdataGPRMCformat(event)

			if gpsData.valid then

				' log GPS events on first event, then no more frequently than every 30 seconds
				logGPSEvent = false
				currentTime = m.bsp.systemTime.GetLocalDateTime()
				if type(m.nextTimeToLogGPSEvent$) = "roString" then
					if currentTime.GetString() > m.nextTimeToLogGPSEvent$ then
						logGPSEvent = true
					endif
				else
					logGPSEvent = true
				endif

				if logGPSEvent then
					currentTime.AddSeconds(30)
					m.nextTimeToLogGPSEvent$ = currentTime.GetString()
				endif

				if gpsData.fixActive then

					if logGPSEvent then
					    m.bsp.logging.WriteDiagnosticLogEntry(m.bsp.diagnosticCodes.EVENT_GPS_LOCATION, str(gpsData.latitude) + ":" + str(gpsData.longitude))
					endif

			        m.bsp.diagnostics.PrintDebug("GPS location: " + str(gpsData.latitude) + "," + str(gpsData.longitude))
					m.bsp.gpsLocation.latitude = gpsData.latitude
					m.bsp.gpsLocation.longitude = gpsData.longitude

					latitudeInRadians = ConvertDecimalDegtoRad(m.bsp.gpsLocation.latitude)
					longitudeInRadians = ConvertDecimalDegtoRad(m.bsp.gpsLocation.longitude)

					for each transition in m.gpsEnterRegionEvents

						distance = CalcGPSDistance (latitudeInRadians, longitudeInRadians, transition.latitudeInRadians, transition.longitudeInRadians)
						m.bsp.diagnostics.PrintDebug("GPS distance from longitude " + str(transition.longitude) + ", latitude " + str(transition.latitude) + " = " + str(distance))

						if distance < transition.radiusInFeet then
							m.bsp.diagnostics.PrintDebug("GPS enter region")
							m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "gpsEnterRegion", str(gpsData.latitude) + ":" + str(gpsData.longitude), "1")
							return m.ExecuteTransition(transition, stateData, "")
						endif

					next

					for each transition in m.gpsExitRegionEvents

						distance = CalcGPSDistance (latitudeInRadians, longitudeInRadians, transition.latitudeInRadians, transition.longitudeInRadians)
						m.bsp.diagnostics.PrintDebug("GPS distance from longitude " + str(transition.longitude) + ", latitude " + str(transition.latitude) + " = " + str(distance))

						if distance > transition.radiusInFeet then
							m.bsp.diagnostics.PrintDebug("GPS exit region")
							m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "gpsExitRegion", str(gpsData.latitude) + ":" + str(gpsData.longitude), "1")
							return m.ExecuteTransition(transition, stateData, "")
						endif

					next

				else
					if logGPSEvent then
					    m.bsp.logging.WriteDiagnosticLogEntry(m.bsp.diagnosticCodes.EVENT_GPS_NOT_LOCKED, "")
					endif

					m.bsp.gpsLocation.latitude = invalid
					m.bsp.gpsLocation.longitude = invalid
				endif
			else
				' print "GPS not valid"
			endif

			stateData.nextState = m.superState
			return "SUPER"

		endif

	    m.bsp.diagnostics.PrintDebug("Serial Line Event " + event.GetString())

        serialEvents = m.serialEvents

        if type(serialEvents) = "roAssociativeArray" then
            if type(serialEvents[port$]) = "roAssociativeArray" then
                if type(serialEvents[port$][serialEvent$]) = "roAssociativeArray" then
					transition = serialEvents[port$][serialEvent$]
					m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "serial", port$ + " " + serialEvent$, "1")
					return m.ExecuteTransition(transition, stateData, serialEvent$)
                else
					' check for wildcards
					serialEvent$ = "<*>"
	                if type(serialEvents[port$][serialEvent$]) = "roAssociativeArray" then
						transition = serialEvents[port$][serialEvent$]
						m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "serial", port$ + " " + event.GetString(), "1")

						if transition.assignInputToUserVariable then
							transition.AssignEventInputToUserVariable(m.bsp, event.GetString())
						endif

						return m.ExecuteTransition(transition, stateData, event.GetString())
					endif
                endif
            endif
        endif
		m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "serial", port$ + " " + serialEvent$, "0")
        
    else if type(event) = "roStreamByteEvent" then
	    m.bsp.diagnostics.PrintDebug("Serial Byte Event " + str(event.GetInt()))
	    
	    serialByte% = event.GetInt()
        port$ = event.GetUserData()

		port% = int(val(port$))
		serialStreamInput = m.stateMachine.serialStreamInputBuffers[port%]
		while serialStreamInput.Count() >= 64
			serialStreamInput.Shift()
		end while
		serialStreamInput.push(serialByte%)

		' compare the serialStreamInput to all expected inputs. execute transition if a match is found.
		if type(m.serialEvents[port$]) = "roAssociativeArray" then
			if type(m.serialEvents[port$].streamInputTransitionSpecs) = "roArray" then
				streamInputTransitionSpecs = m.serialEvents[port$].streamInputTransitionSpecs
				for i% = 0 to streamInputTransitionSpecs.Count() - 1
					streamInputTransitionSpec = streamInputTransitionSpecs[i%]
					streamInputSpec = streamInputTransitionSpec.inputSpec
					
					if ByteArraysMatch(serialStreamInput, streamInputSpec) then
						serialStreamInput.Clear()
						m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "serialBytes", port$ + " " + streamInputTransitionSpec.asciiSpec, "1")
						return m.ExecuteTransition(streamInputTransitionSpec.transition, stateData, "")
					endif
				next
			endif
		endif

	else if type(event) = "roUsbBinaryEtapEvent" then

	    m.bsp.diagnostics.PrintDebug("UsbBinaryEtap Event " + event.GetByteArray().ToHexString())
	    
	    ba = event.GetByteArray()
	    	    
	    ' compare the byte array received to all expected inputs. execute transition if a match is found.
	    if type(m.usbBinaryEtapEvents) = "roArray" then
            for each usbBinaryEtapInputTransitionSpec in m.usbBinaryEtapEvents
				if ByteArraysMatch(usbBinaryEtapInputTransitionSpec.inputSpec, ba) then
					m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "usbBinaryEtap", usbBinaryEtapInputTransitionSpec.asciiSpec, "1")
					return m.ExecuteTransition(usbBinaryEtapInputTransitionSpec.transition, stateData, "")
				endif
            next
        endif
			
    else if type(event) = "roIRRemotePress" then
		m.bsp.diagnostics.PrintDebug("Remote Event" + stri(event.GetInt()))

		remoteEvent% = event.GetInt()
		remoteEvent$ = ConvertToRemoteCommand(remoteEvent%)
    
		remoteEvents = m.remoteEvents
    
		if type(remoteEvents) = "roAssociativeArray" then
			if type(remoteEvents[remoteEvent$]) = "roAssociativeArray" then
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "remote", remoteEvent$, "1")
				return m.ExecuteTransition(m.remoteEvents[remoteEvent$], stateData, remoteEvent$)
			endif
		endif            
		m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "remote", remoteEvent$, "0")

    else if type(event) = "roKeyboardPress" then
    
		' note - this code does not fully cover the case where one state is waiting for keyboard input
		' and another state is waiting for barcode input.
	    
		m.bsp.diagnostics.PrintDebug("Keyboard Press" + str(event.GetInt()))

		keyboardChar$ = chr(event.GetInt())

        usbStringEvents = m.usbStringEvents
        keyboardEvents = m.keyboardEvents

        checkUSBInputString = false
        if type(usbStringEvents) = "roAssociativeArray" then
            if event.GetInt() <> 13 then
                m.usbInputBuffer$ = m.usbInputBuffer$ + keyboardChar$
                checkUSBInputString = false
            else
                checkUSBInputString = true
            endif
        endif
                    
        ' check for bar code input (usb characters terminated by an Enter key)
        if type(usbStringEvents) = "roAssociativeArray" then
            if checkUSBInputString then
				if type(usbStringEvents[m.usbInputBuffer$]) = "roAssociativeArray" then
					m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "usb", m.usbInputBuffer$, "1")
					action$ = m.ExecuteTransition(m.usbStringEvents[m.usbInputBuffer$], stateData, m.usbInputBuffer$)
					if event.GetInt() = 13 then m.usbInputBuffer$ = ""
					return action$
				else
					' check for wildcards
					usbInputBuffer$ = "<any>"
					if type(usbStringEvents[usbInputBuffer$]) = "roAssociativeArray" then
						m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "usb", m.usbInputBuffer$, "1")
						action$ = m.ExecuteTransition(m.usbStringEvents[usbInputBuffer$], stateData, m.usbInputBuffer$)
						if event.GetInt() = 13 then m.usbInputBuffer$ = ""
						return action$
					endif
				endif
            endif
        endif

        ' check for single keyboard characters
		keyboardPayload$ = keyboardChar$
        if type(keyboardEvents) = "roAssociativeArray" then        
                                
			' if keyboard input is non printable character, convert it to the special code
			keyboardCode$ = m.bsp.GetNonPrintableKeyboardCode(event.GetInt())
			if keyboardCode$ <> "" then
				keyboardChar$ = keyboardCode$
				keyboardPayload$ = keyboardChar$
			endif

            if type(keyboardEvents[keyboardChar$]) = "roAssociativeArray" then
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "keyboard", keyboardChar$, "1")
				action$ = m.ExecuteTransition(m.keyboardEvents[keyboardChar$], stateData, keyboardPayload$)
		        if event.GetInt() = 13 then m.usbInputBuffer$ = ""
				return action$
            else if type(keyboardEvents["<any>"]) = "roAssociativeArray" then
				keyboardChar$ = "<any>"
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "keyboard", keyboardChar$, "1")
				action$ = m.ExecuteTransition(m.keyboardEvents[keyboardChar$], stateData, keyboardPayload$)
				if event.GetInt() = 13 then m.usbInputBuffer$ = ""
				return action$
			endif
        endif        

		m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "usb", keyboardChar$, "0")

        ' clear the buffer when the user presses enter
        if event.GetInt() = 13 then m.usbInputBuffer$ = ""
    
    else if type(event) = "roDatagramEvent" then

		' could be either a udp event or a synchronize event
    
		m.bsp.diagnostics.PrintDebug("UDP Event " + event.GetString())
    
		udpEvent$ = event.GetString()
    
        synchronizeEvents = m.synchronizeEvents
        udpEvents = m.udpEvents
            
        ' check to see if this is a synchronization preload or play event
        if type(synchronizeEvents) = "roAssociativeArray" then
            index% = instr(1, udpEvent$, "pre-")
            if index% = 1 then
                ' preload next file
                synchronizeEvent$ = mid(udpEvent$, 5)
                if type(synchronizeEvents[synchronizeEvent$]) = "roAssociativeArray" then
                
                    ' get the next file and preload it
                    nextState$ = synchronizeEvents[synchronizeEvent$].targetMediaState$
				    nextState = m.stateMachine.stateTable[nextState$]

                    preloadRequired = true
                    if type(m.stateMachine.preloadState) = "roAssociativeArray" then
                        if m.stateMachine.preloadedStateName$ = nextState.name$
                            preloadRequired = false
                        endif
                    endif                                    

                    ' set this variable so that launchVideo knows what has been preloaded
                    m.stateMachine.preloadState = nextState
                    
                    ' currently only support preload / synchronizing with images and videos
                    if preloadRequired then
                        m.stateMachine.preloadState.PreloadItem()
                    endif

					m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "synchronize-pre", synchronizeEvent$, "1")

					' ?? return "HANDLED" ??
                endif
            endif
            index% = instr(1, udpEvent$, "ply-")
            if index% = 1 then
                ' just transition to the next state where the file will be played
                synchronizeEvent$ = mid(udpEvent$, 5)
                if type(synchronizeEvents[synchronizeEvent$]) = "roAssociativeArray" then
					m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "synchronize-play", synchronizeEvent$, "1")
					return m.ExecuteTransition(m.synchronizeEvents[synchronizeEvent$], stateData, "")
                endif
            endif
		endif

        if type(udpEvents) = "roAssociativeArray" then
            if type(udpEvents[udpEvent$]) = "roAssociativeArray" then
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "udp", udpEvent$, "1")
				transition = udpEvents[udpEvent$]
				return m.ExecuteTransition(transition, stateData, udpEvent$)
            else
				' check for wildcards
				udpEvent$ = "<any>"
	            if type(udpEvents[udpEvent$]) = "roAssociativeArray" then
					m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "udp", event.GetString(), "1")
					transition = udpEvents[udpEvent$]

					if transition.assignInputToUserVariable then
						transition.AssignEventInputToUserVariable(m.bsp, event.GetString())
					endif

					return m.ExecuteTransition(transition, stateData, event.GetString())
				endif
            endif
        endif          

		m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "udp", event.GetString(), "0")
        
    else if type(event) = "roAssociativeArray" then      ' internal message event
        if IsString(event["EventType"]) then
        
			if event["EventType"] = "BPControlDown" then
				bpIndex$ = event["ButtonPanelIndex"]
				bpIndex% = int(val(bpIndex$))
				bpNum$ = event["ButtonNumber"]
				bpNum% = int(val(bpNum$))
				m.bsp.diagnostics.PrintDebug("BP Press" + bpNum$ + " on button panel" + bpIndex$)
				bpEvents = m.bpEvents

				' bpEvents["-1"] => any bp button
				currentBPEvent = bpEvents[bpIndex%]
				transition = currentBPEvent[bpNum$]
				if type(transition) <> "roAssociativeArray" then
					transition = currentBPEvent["-1"]
				endif
				
				if type(transition) = "roAssociativeArray" then
					payload$ = bpIndex$ + "-" + StripLeadingSpaces(stri(bpNum% + 1))
					m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "bpDown", bpIndex$ + " " + bpNum$, "1")
					return m.ExecuteTransition(transition, stateData, payload$)
				endif 
				
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "bpDown", bpIndex$ + " " + bpNum$, "0")

	        else if event["EventType"] = "SEND_ZONE_MESSAGE" then
	        
				sendZoneMessageParameter$ = event["EventParameter"]

				m.bsp.diagnostics.PrintDebug("ZoneMessageEvent " + sendZoneMessageParameter$)

                if type(m.zoneMessageEvents) = "roAssociativeArray" then
					if type(m.zoneMessageEvents[sendZoneMessageParameter$]) = "roAssociativeArray" then
						m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "sendZoneMessage", sendZoneMessageParameter$, "1")
						return m.ExecuteTransition(m.zoneMessageEvents[sendZoneMessageParameter$], stateData, "")
					endif
				endif

				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "sendZoneMessage", sendZoneMessageParameter$, "0")

				return "HANDLED"
							
	        else if event["EventType"] = "INTERNAL_SYNC_PRELOAD" then

				internalSyncParameter$ = event["EventParameter"]

				m.bsp.diagnostics.PrintDebug("InternalSyncPreloadEvent " + internalSyncParameter$)

				actedOn$ = "0"

                if type(m.internalSynchronizeEvents) = "roAssociativeArray" then
					if type(m.internalSynchronizeEvents[internalSyncParameter$]) = "roAssociativeArray" then
						nextState$ = m.internalSynchronizeEvents[internalSyncParameter$].targetMediaState$
		                m.stateMachine.preloadState = m.stateMachine.stateTable[nextState$]
						m.stateMachine.preloadState.PreloadItem()
						actedOn$ = "1"
					endif
				endif

				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "internalSyncPreload", internalSyncParameter$, actedOn$)

				return "HANDLED"
							
            else if event["EventType"] = "INTERNAL_SYNC_MASTER_PRELOAD" then

				internalSyncParameter$ = event["EventParameter"]

				m.bsp.diagnostics.PrintDebug("InternalSyncMasterPreload " + internalSyncParameter$)

				actedOn$ = "0"

                if type(m.internalSynchronizeEventsMaster) = "roAssociativeArray" then
					if type(m.internalSynchronizeEventsMaster[internalSyncParameter$]) = "roAssociativeArray" then
	                    m.bsp.diagnostics.PrintDebug("post play message with parameter " + internalSyncParameter$)
						internalSyncPlay = CreateObject("roAssociativeArray")
						internalSyncPlay["EventType"] = "INTERNAL_SYNC_PLAY"
						internalSyncPlay["EventParameter"] = internalSyncParameter$
						m.stateMachine.msgPort.PostMessage(internalSyncPlay)
						actedOn$ = "1"
					endif
                endif
            
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "internalSyncMasterPreload", internalSyncParameter$, actedOn$)

                return "HANDLED"

	        else if event["EventType"] = "INTERNAL_SYNC_PLAY" then

				internalSyncParameter$ = event["EventParameter"]

				m.bsp.diagnostics.PrintDebug("InternalSyncPlayEvent " + internalSyncParameter$)

                if type(m.internalSynchronizeEventsMaster) = "roAssociativeArray" then
					if type(m.internalSynchronizeEventsMaster[internalSyncParameter$]) = "roAssociativeArray" then
                        m.bsp.diagnostics.PrintDebug("master play event received - prepare to return")
						m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "internalSyncMasterPlay", internalSyncParameter$, "1")
						return m.ExecuteTransition(m.internalSynchronizeEventsMaster[internalSyncParameter$], stateData, "")
					endif
				endif

                if type(m.internalSynchronizeEvents) = "roAssociativeArray" then
					if type(m.internalSynchronizeEvents[internalSyncParameter$]) = "roAssociativeArray" then
                        m.bsp.diagnostics.PrintDebug("slave play event received - prepare to return")
						m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "internalSyncSlavePlay", internalSyncParameter$, "1")
						return m.ExecuteTransition(m.internalSynchronizeEvents[internalSyncParameter$], stateData, "")
					endif
				endif
	
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "internalSyncPlay", internalSyncParameter$, "0")

            else if event["EventType"] = "PREPARE_FOR_RESTART" then

                m.bsp.diagnostics.PrintDebug(m.id$ + " - PREPARE_FOR_RESTART")

				if type(m.stateMachine.videoPlayer) = "roVideoPlayer" then
					m.stateMachine.videoPlayer = invalid
				endif
				
				if IsAudioPlayer(m.stateMachine.audioPlayer) then
					m.stateMachine.audioPlayer = invalid
				endif
				
				if type(m.stateMachine.imagePlayer) = "roImageWidget" then
					m.stateMachine.imagePlayer = invalid
				endif
	            
				if type(m.stateMachine.feedPlayer) = "roAssociativeArray" then
					m.stateMachine.feedPlayer = invalid
				endif
				
				return "HANDLED"
				
			endif
		endif

	else if (type(event) = "roVideoEvent" and type(m.stateMachine.videoPlayer) = "roVideoPlayer" and event.GetSourceIdentity() = m.stateMachine.videoPlayer.GetIdentity()) or (type(event) = "roAudioEvent" and IsAudioPlayer(m.stateMachine.audioPlayer) and event.GetSourceIdentity() = m.stateMachine.audioPlayer.GetIdentity()) then

        if event.GetInt() = 8 then
			m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "mediaEnd", "", "0")
        else if event.GetInt() = 12 then
			m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "videoTimeCode", "", "0")
		endif

    endif
               
    stateData.nextState = m.superState
    return "SUPER"
               
End Function


' m is bsp
Sub WaitForSyncResponse(parameter$ As String)

    udpReceiver = CreateObject("roDatagramReceiver", m.udpReceivePort)
    msgPort = CreateObject("roMessagePort")
    udpReceiver.SetPort(msgPort)

    m.udpSender.Send("ply-" + parameter$)
    
    while true
        msg = wait(50, msgPort)
        if type(msg) = "roDatagramEvent" or msg = invalid then
            udpReceiver = invalid
            return
		endif
    endwhile
    
End Sub


Function EventActiveToday(currentDateTime As Object, daysOfWeek% As Integer) As Boolean

	bitwiseDaysOfWeek% = daysOfWeek%
	currentDayOfWeek = currentDateTime.GetDayOfWeek()
	bitDayOfWeek% = 2 ^ currentDayOfWeek
	if (bitwiseDaysOfWeek% and bitDayOfWeek%) <> 0 then
		return true
	endif

	return false

End Function


Function TimeWithinWindow(currentTime% As Integer, startTime% As Integer, endTime% As Integer) As Boolean

	withinWindow = false

	if startTime% = endTime% then
		withinWindow = true
	else if startTime% < endTime% then
		if currentTime% >= startTime% and currentTime% < endTime% then
			withinWindow = true
		endif
	else if currentTime% < endTime% or currentTime% > startTime% then
		withinWindow = true
	endif

	return withinWindow

End Function


Function IsTimeoutInFuture(timeoutDateTime As Object) As Boolean

	systemTime = CreateObject("roSystemTime")
	currentDateTime = systemTime.GetLocalDateTime()
	systemTime = invalid

	return currentDateTime.GetString() < timeoutDateTime.GetString()

End Function


Sub LaunchTimeClockEventTimer(state As Object, timeClockEvent As Object)

	timer = CreateObject("roTimer")

	if type(timeClockEvent.timeClockEventDateTime) = "roDateTime" then

		dateTime = timeClockEvent.timeClockEventDateTime

		' only set timer if it is in the future
		if not IsTimeoutInFuture(dateTime) then
			return
		endif

        state.bsp.diagnostics.PrintDebug("Set timeout to " + dateTime.GetString())
		timer.SetDateTime(dateTime)

	else if type(timeClockEvent.userVariableName$) = "roString" then
		if type(timeClockEvent.userVariable) = "roAssociativeArray" then
			dateTime$ = timeClockEvent.userVariable.GetCurrentValue()
			dateTime = FixDateTime(dateTime$)

			if type(dateTime) = "roDateTime" then
				' only set timer if it is in the future
				if not IsTimeoutInFuture(dateTime) then
					print "Specified timer is in the past, don't set it: timer time is ";dateTime.GetString()
					return
				endif

		        state.bsp.diagnostics.PrintDebug("Set timeout to " + dateTime.GetString())
				timer.SetDateTime(dateTime)
			else
		        state.bsp.diagnostics.PrintDebug("Timeout specification " + dateTime$ + " is invalid")
				state.bsp.logging.WriteDiagnosticLogEntry(state.bsp.diagnosticCodes.EVENT_INVALID_DATE_TIME_SPEC, dateTime$)
			endif
		endif
	else if type(timeClockEvent.timeClockDaily%) = "roInt" then
		hours% = timeClockEvent.timeClockDaily% / 60
		minutes% = timeClockEvent.timeClockDaily% - (hours% * 60)
		timer.SetTime(hours%, minutes%, 0, 0)
		timer.SetDate(-1, -1, -1)
	else
	    systemTime = CreateObject("roSystemTime")
		currentDateTime = systemTime.GetLocalDateTime()
			
		' units in seconds rather than minutes?
		currentTime% = currentDateTime.GetHour() * 60 + currentDateTime.GetMinute()
		startTime% = timeClockEvent.timeClockPeriodicStartTime%
		endTime% = timeClockEvent.timeClockPeriodicEndTime%
		intervalTime% = timeClockEvent.timeClockPeriodicInterval%

		withinWindow = TimeWithinWindow(currentTime%, startTime%, endTime%)

'		print "currentDateTime = ";currentDateTime.GetString()
'		print "currentTime% = ";currentTime%
'		print "withinWindow = ";withinWindow

		if not withinWindow then
			' set timer for next start time
			hours% = startTime% / 60
			minutes% = startTime% - (hours% * 60)
			timer.SetTime(hours%, minutes%, 0, 0)
			timer.SetDate(-1, -1, -1)
'			print "set time to ";hours%;" hours, ";minutes%;" minutes"
		else
			' set timer for next appropriate time
			if currentTime% > startTime% then
				minutesSinceStartTime% = currentTime% - startTime%
			else
				minutesSinceStartTime% = currentTime% + (24 * 60 - startTime%)
			endif

			' elapsed intervals since the start time?
			numberOfElapsedIntervals% = minutesSinceStartTime% / intervalTime%
			numberOfIntervalsUntilNextTimeout% = numberOfElapsedIntervals% + 1

			' determine time for next timeout
			nextTimeoutTime% = startTime% + (numberOfIntervalsUntilNextTimeout% * intervalTime%)

			' check for wrap to next day
			if nextTimeoutTime% > (24 * 60) then
				nextTimeoutTime% = nextTimeoutTime% - (24 * 60)
			endif

			' set timer for next start time
			hours% = nextTimeoutTime% / 60
			minutes% = nextTimeoutTime% - (hours% * 60)
			timer.SetTime(hours%, minutes%, 0, 0)
			timer.SetDate(-1, -1, -1)

		    state.bsp.diagnostics.PrintDebug("Set timeout to " + stri(hours%) + " hours, " + stri(minutes%) + " minutes.")

		endif

		systemTime = invalid

	endif

    timer.SetPort(state.stateMachine.msgPort)
    timer.Start()
    timeClockEvent.timer = timer

End Sub


Sub LaunchTimer()

    if type(m.mstimeoutEvent) = "roAssociativeArray" then
    
        timer = CreateObject("roTimer")
        timer.SetPort(m.stateMachine.msgPort)
        systemTime = CreateObject("roSystemTime")
        newTimeout = systemTime.GetLocalDateTime()
        newTimeout.AddMilliseconds(m.mstimeoutValue%)
        timer.SetDateTime(newTimeout)
        timer.Start()
        m.mstimeoutTimer = timer

	else if type(m.timeClockEvents) = "roArray" then
	
		for each timeClockEvent in m.timeClockEvents
			LaunchTimeClockEventTimer(m, timeClockEvent)
		next

	endif

End Sub


Sub PreloadItem()

	zone = m.stateMachine
	
	if m.type$ = "mediaList" or m.type$ = "mediaRSS" or m.type$ = "signChannel" or m.type$ = "liveText" or m.type$ = "interactiveMenuItem" then
		zone.preloadedStateName$ = ""
		return
	endif

	if m.type$ = "playFile" then
		fileTableEntry = m.filesTable.Lookup(m.payload$)
		fileName$ = fileTableEntry.fileName$
		fileType$ = fileTableEntry.fileType$
		if fileType$ = "image" then
			imageItem = {}
			imageItem.fileName$ = fileName$
			imageItem.useImageBuffer = false
		else if fileType$ = "video" then
			videoItem = {}
			videoItem.fileName$ = fileName$
			videoItem.probeData = fileTableEntry.probeData
		endif
	else if type(m.imageItem) = "roAssociativeArray" then
		imageItem = {}
		imageItem.fileName$ = m.imageItem.fileName$
		imageItem.useImageBuffer = m.imageItem.useImageBuffer
	else if type(m.videoItem) = "roAssociativeArray" then
		videoItem = {}
		videoItem.fileName$ = m.videoItem.fileName$
		if type(m.videoItem.probeData) = "roString" then
			videoItem.probeData = m.videoItem.probeData
		else
			videoItem.probeData = invalid
		endif
	endif

    if type(imageItem) = "roAssociativeArray" then
        if imageItem.useImageBuffer = true then
			m.bsp.diagnostics.PrintDebug("Did not preload file in PreloadItem as it is using an image buffer: " + imageItem.fileName$)
        else
			imageItemFilePath$ = GetPoolFilePath(m.bsp.syncPoolFiles, imageItem.fileName$)
			zone.imagePlayer.PreloadFile(imageItemFilePath$)
			zone.preloadedStateName$ = m.name$
			m.bsp.diagnostics.PrintDebug("Preloaded file in PreloadItem: " + imageItem.fileName$ + ", " + imageItemFilePath$)
        endif
    else if type(videoItem) = "roAssociativeArray" then
        videoItemFilePath$ = GetPoolFilePath(m.bsp.syncPoolFiles, videoItem.fileName$)

		aa = { }
		aa.AddReplace("Filename", videoItemFilePath$)
		
		if type(videoItem.probeData) = "roString" then
			m.bsp.diagnostics.PrintDebug("PreloadItem: probeData = " + videoItem.probeData)
			aa.AddReplace("ProbeString", videoItem.probeData)
		endif

		ok = zone.videoPlayer.PreloadFile(aa)
        zone.preloadedStateName$ = m.name$
        m.bsp.diagnostics.PrintDebug("Preloaded file in PreloadItem: " + videoItem.fileName$)
    endif

End Sub

'endregion

'region Images State Machine
' *************************************************
'
' Images State Machine
'
' *************************************************
Function newImagesZoneHSM(bsp As Object, zoneXML As Object) As Object

    zoneHSM = newHSM()
	zoneHSM.ConstructorHandler = ImageZoneConstructor
	zoneHSM.InitialPseudostateHandler = ImageZoneGetInitialState

    newZoneCommon(bsp, zoneXML, zoneHSM)
    
    zoneHSM.imageMode% = GetImageModeValue(zoneXML.zoneSpecificParameters.imageMode.GetText())

	zoneHSM.numImageItems% = 0
	
    return zoneHSM
    
End Function


Sub ImageZoneConstructor()

	m.InitializeZoneCommon(m.bsp.msgPort)
	
    zoneHSM = m
    
	if zoneHSM.numImageItems% > 0 then

		imagePlayer = CreateObject("roImageWidget", zoneHSM.rectangle)
	    
		zoneHSM.imagePlayer = imagePlayer
	    
		' initialize image player parameters
		imagePlayer.SetDefaultMode(zoneHSM.imageMode%)

		m.LoadImageBuffers()

	else
	
		zoneHSM.imagePlayer = invalid
		
	endif
	
	m.CreateObjects()
	
	m.activeState = m.playlist.firstState
	m.previousStateName$ = m.playlist.firstStateName$
		
End Sub


Function ImageZoneGetInitialState() As Object

	return m.activeState

End Function


Function STDisplayingImageEventHandler(event As Object, stateData As Object) As Object

    stateData.nextState = invalid
    
    if type(event) = "roAssociativeArray" then      ' internal message event

        if IsString(event["EventType"]) then
        
            if event["EventType"] = "ENTRY_SIGNAL" then
            
                m.bsp.diagnostics.PrintDebug(m.id$ + ": entry signal")

				m.DisplayImage("image")

                return "HANDLED"

            else if event["EventType"] = "EXIT_SIGNAL" then

                m.bsp.diagnostics.PrintDebug(m.id$ + ": exit signal")
            
            else
            
		        return m.MediaItemEventHandler(event, stateData)

            endif
            
        endif
    else
        return m.MediaItemEventHandler(event, stateData)
    endif
            
    stateData.nextState = m.superState
    return "SUPER"
    
End Function

'endregion

'region Enhanced Audio State Machine
' *************************************************
'
' Enhanced Audio State Machine
'
' *************************************************
Function newEnhancedAudioZoneHSM(bsp As Object, zoneXML As Object) As Object
    
	zoneHSM = newHSM()
	zoneHSM.ConstructorHandler = EnhancedAudioZoneConstructor
	zoneHSM.InitializeAudioZoneCommon = InitializeAudioZoneCommon
	zoneHSM.InitialPseudostateHandler = EnhancedAudioZoneGetInitialState

    newZoneCommon(bsp, zoneXML, zoneHSM)
    newAudioZoneCommon(zoneXML, zoneHSM)
    
	zoneHSM.fadeLength% = 4
	fadeLength$ = zoneXML.zoneSpecificParameters.fadeLength.GetText()
	if fadeLength$ <> "" then
		zoneHSM.fadeLength% = int(val(fadeLength$))
	endif

    return zoneHSM

End Function


Sub EnhancedAudioZoneConstructor()

    audioPlayer = CreateObject("roAudioPlayerMx")
	m.InitializeAudioZoneCommon(audioPlayer)

End Sub


Function EnhancedAudioZoneGetInitialState() As Object

	return m.activeState

End Function

'endregion

'region Audio State Machine
' *************************************************
'
' Audio State Machine
'
' *************************************************
Function newAudioZoneHSM(bsp As Object, zoneXML As Object) As Object

    zoneHSM = newHSM()
	zoneHSM.ConstructorHandler = AudioZoneConstructor
	zoneHSM.InitializeAudioZoneCommon = InitializeAudioZoneCommon
	zoneHSM.InitialPseudostateHandler = AudioZoneGetInitialState

    newZoneCommon(bsp, zoneXML, zoneHSM)
    newAudioZoneCommon(zoneXML, zoneHSM)

    return zoneHSM

End Function


Sub newAudioZoneCommon(zoneXML As Object, zoneHSM As Object)

    zoneHSM.audioOutput% = GetAudioOutputValue(zoneXML.zoneSpecificParameters.audioOutput.GetText())
    zoneHSM.audioMode% = GetAudioModeValue(zoneXML.zoneSpecificParameters.audioMode.GetText())
    zoneHSM.audioMapping% = GetAudioMappingValue(zoneXML.zoneSpecificParameters.audioMapping.GetText())
	zoneHSM.audioMappingSpan% = GetAudioMappingSpan(zoneHSM.audioOutput%, zoneXML.zoneSpecificParameters.audioMapping.GetText())

	zoneHSM.analogOutput$ = zoneXML.zoneSpecificParameters.analogOutput.GetText()
	zoneHSM.analog2Output$ = zoneXML.zoneSpecificParameters.analog2Output.GetText()
	zoneHSM.analog3Output$ = zoneXML.zoneSpecificParameters.analog3Output.GetText()
	zoneHSM.hdmiOutput$ = zoneXML.zoneSpecificParameters.hdmiOutput.GetText()
	zoneHSM.spdifOutput$ = zoneXML.zoneSpecificParameters.spdifOutput.GetText()
	zoneHSM.usbOutput$ = zoneXML.zoneSpecificParameters.usbOutput.GetText()
	zoneHSM.audioMixMode$ = zoneXML.zoneSpecificParameters.audioMixMode.GetText()

	if zoneHSM.analogOutput$ <> "" and zoneHSM.hdmiOutput$ <> "" and zoneHSM.spdifOutput$ <> "" and zoneHSM.audioMixMode$ <> "" then
		zoneHSM.presentationUsesRoAudioOutputParameters = true
	else
		zoneHSM.presentationUsesRoAudioOutputParameters = false
	endif

    zoneHSM.initialAudioVolume% = 100
    audioVolume$ = zoneXML.zoneSpecificParameters.audioVolume.GetText()
    if audioVolume$ <> "" then
        zoneHSM.initialAudioVolume% = int(val(audioVolume$))
    endif

End Sub


Sub InitializeAudioZoneCommon(audioPlayer As Object)

	m.InitializeZoneCommon(m.bsp.msgPort)
	
    zoneHSM = m
    
    ' create players
    
    zoneHSM.audioVolume% = zoneHSM.initialAudioVolume%
    
    zoneHSM.audioChannelVolumes = CreateObject("roArray", 6, true)
    for i% = 0 to 5
        zoneHSM.audioChannelVolumes[i%] = zoneHSM.audioVolume%
    next
    
    ' initialize audio player parameters
    audioPlayer.SetPort(zoneHSM.msgPort)
    
    zoneHSM.audioPlayer = audioPlayer
    
	m.SetAudioOutputAndMode(audioPlayer)

    ' audioPlayer.SetAudioOutput(zoneHSM.audioOutput%)
    ' audioPlayer.SetAudioMode(zoneHSM.audioMode%)
    audioPlayer.MapStereoOutput(zoneHSM.audioMapping%)
	audioPlayer.SetStereoMappingSpan(zoneHSM.audioMappingSpan%)
    audioPlayer.SetVolume(zoneHSM.audioVolume%)
    audioPlayer.SetLoopMode(false)

	' Panther only
	zoneHSM.ConfigureAudioResources()

	zoneHSM.audioPlayerAudioSettings = CreateObject("roAssociativeArray")
	zoneHSM.audioPlayerAudioSettings.audioOutput% = zoneHSM.audioOutput%
	zoneHSM.audioPlayerAudioSettings.stereoMapping% = zoneHSM.audioMapping%
	zoneHSM.audioPlayerAudioSettings.audioMappingSpan% = zoneHSM.audioMappingSpan%
	m.bsp.SetAudioVolumeLimits(zoneHSM.audioPlayerAudioSettings) 

	m.activeState = m.playlist.firstState
	m.previousStateName$ = m.playlist.firstStateName$
	
	m.CreateObjects()

End Sub


Sub AudioZoneConstructor()

    audioPlayer = CreateObject("roAudioPlayer")
	m.InitializeAudioZoneCommon(audioPlayer)

End Sub


Function AudioZoneGetInitialState() As Object

	return m.activeState

End Function

'endregion

'region Video State Machine
' *************************************************
'
' Video State Machine
'
' *************************************************
Function newVideoZoneHSM(bsp As Object, zoneXML As Object) As Object

    zoneHSM = newHSM()

	zoneHSM.InitializeVideoZoneObjects = InitializeVideoZoneObjects
	zoneHSM.ConstructorHandler = VideoZoneConstructor
	zoneHSM.InitialPseudostateHandler = VideoZoneGetInitialState

    newZoneCommon(bsp, zoneXML, zoneHSM)
    
    zoneHSM.viewMode% = GetViewModeValue(zoneXML.zoneSpecificParameters.viewMode.GetText())
    zoneHSM.audioOutput% = GetAudioOutputValue(zoneXML.zoneSpecificParameters.audioOutput.GetText())
    zoneHSM.audioMode% = GetAudioModeValue(zoneXML.zoneSpecificParameters.audioMode.GetText())
    zoneHSM.audioMapping% = GetAudioMappingValue(zoneXML.zoneSpecificParameters.audioMapping.GetText())
	zoneHSM.audioMappingSpan% = GetAudioMappingSpan(zoneHSM.audioOutput%, zoneXML.zoneSpecificParameters.audioMapping.GetText())
	
	zoneHSM.analogOutput$ = zoneXML.zoneSpecificParameters.analogOutput.GetText()
	zoneHSM.analog2Output$ = zoneXML.zoneSpecificParameters.analog2Output.GetText()
	zoneHSM.analog3Output$ = zoneXML.zoneSpecificParameters.analog3Output.GetText()
	zoneHSM.hdmiOutput$ = zoneXML.zoneSpecificParameters.hdmiOutput.GetText()
	zoneHSM.spdifOutput$ = zoneXML.zoneSpecificParameters.spdifOutput.GetText()
	zoneHSM.usbOutput$ = zoneXML.zoneSpecificParameters.usbOutput.GetText()
	zoneHSM.audioMixMode$ = zoneXML.zoneSpecificParameters.audioMixMode.GetText()

	if zoneHSM.analogOutput$ <> "" and zoneHSM.hdmiOutput$ <> "" and zoneHSM.spdifOutput$ <> "" and zoneHSM.audioMixMode$ <> "" then
		zoneHSM.presentationUsesRoAudioOutputParameters = true
	else
		zoneHSM.presentationUsesRoAudioOutputParameters = false
	endif

    zoneHSM.initialVideoVolume% = 100
    videoVolume$ = zoneXML.zoneSpecificParameters.videoVolume.GetText()
    if videoVolume$ <> "" then
        zoneHSM.initialVideoVolume% = int(val(videoVolume$))
    endif
    
    zoneHSM.initialAudioVolume% = 100
    audioVolume$ = zoneXML.zoneSpecificParameters.audioVolume.GetText()
    if audioVolume$ <> "" then
        zoneHSM.initialAudioVolume% = int(val(audioVolume$))
    endif
    
    zoneHSM.videoInput$ = zoneXML.zoneSpecificParameters.liveVideoInput.GetText()
    zoneHSM.videoStandard$ = zoneXML.zoneSpecificParameters.liveVideoStandard.GetText()
    zoneHSM.brightness% = int(val(zoneXML.zoneSpecificParameters.brightness.GetText()))
    zoneHSM.contrast% = int(val(zoneXML.zoneSpecificParameters.contrast.GetText()))
    zoneHSM.saturation% = int(val(zoneXML.zoneSpecificParameters.saturation.GetText()))
    zoneHSM.hue% = int(val(zoneXML.zoneSpecificParameters.hue.GetText()))
    
	zoneHSM.zOrderFront = true
	zOrderFront$ = zoneXML.zoneSpecificParameters.zOrderFront.GetText()
	if lcase(zOrderFront$) = "false" then
		zoneHSM.zOrderFront = false
	endif

    return zoneHSM

End Function


' use roAudioOutput if all of the following are true
'		current device supports roAudioOutput (m.bsp.sysInfo.modelSupportsRoAudioOutput)
'		current presentation was published for a device that supports roAudioOutput (m.bsp.currentPresentationUsesRoAudioOutputParameters)
'		current presentation includes parameters for roAudioOutput (m.presentationUsesRoAudioOutputParameters)
'			this only applies to Panther. Old Panther presentations did not use roAudioOutput parameters
Sub SetAudioOutputAndMode(player As Object)
	
	if m.bsp.sysInfo.modelSupportsRoAudioOutput and m.presentationUsesRoAudioOutputParameters and m.bsp.currentPresentationUsesRoAudioOutputParameters then

		pcm = CreateObject("roArray", 1, true)
		compressed = CreateObject("roArray", 1, true)
		multichannel = CreateObject("roArray", 1, true)

		analogAudioOutput = CreateObject("roAudioOutput", "Analog:1")
		analog2AudioOutput = CreateObject("roAudioOutput", "Analog:2")
		analog3AudioOutput = CreateObject("roAudioOutput", "Analog:3")
		hdmiAudioOutput = CreateObject("roAudioOutput", "HDMI")
		spdifAudioOutput = CreateObject("roAudioOutput", "SPDIF")
		usbAudioOutput = CreateObject("roAudioOutput", "USB")

		if lcase(m.analogOutput$) <> "none" and lcase(m.analogOutput$) <> "multichannel" then
			pcm.push(analogAudioOutput)
		endif

		if lcase(m.analog2Output$) = "pcm" then
			pcm.push(analog2AudioOutput)
		endif

		if lcase(m.analog3Output$) = "pcm" then
			pcm.push(analog3AudioOutput)
		endif

		if lcase(m.analogOutput$)="multichannel" then
			multichannel.push(analogAudioOutput)
		else if lcase(m.analog2Output$)="multichannel" then
			multichannel.push(analog2AudioOutput)
		else if lcase(m.analog3Output$)="multichannel" then
			multichannel.push(analog3AudioOutput)
		endif

		if lcase(m.hdmiOutput$) = "passthrough" then
			compressed.push(hdmiAudioOutput)
		else if lcase(m.hdmiOutput$) <> "none" then
			pcm.push(hdmiAudioOutput)
		endif

		if lcase(m.spdifOutput$) = "passthrough" then
			compressed.push(spdifAudioOutput)
		else if lcase(m.spdifOutput$) <> "none" then
			pcm.push(spdifAudioOutput)
		endif

		if lcase(m.usbOutput$) = "pcm" then
			pcm.push(usbAudioOutput)
		else if lcase(m.usbOutput$) = "multichannel" then
			multichannel.push(usbAudioOutput)
		endif

		if pcm.Count() = 0 then
			noPCMAudioOutput = CreateObject("roAudioOutput", "none")
			pcm.push(noPCMAudioOutput)
		endif

		if compressed.Count() = 0 then
			noCompressedAudioOutput = CreateObject("roAudioOutput", "none")
			compressed.push(noCompressedAudioOutput)
		endif

		if multichannel.Count() = 0 then
			noMultichannelAudioOutput = CreateObject("roAudioOutput", "none")
			multichannel.push(noMultichannelAudioOutput)
		endif

		player.SetPcmAudioOutputs(pcm)
		player.SetCompressedAudioOutputs(compressed)
		player.SetMultichannelAudioOutputs(multichannel)

		if lcase(m.audioMixMode$) = "passthrough" then
			player.SetAudioMode(0)
		else if lcase(m.audioMixMode$) = "left" then
			player.SetAudioMode(3)
		else if lcase(m.audioMixMode$) = "right" then
			player.SetAudioMode(4)
		else
			player.SetAudioMode(1)
		endif

	else
	
		player.SetAudioOutput(m.audioOutput%)
		player.SetAudioMode(m.audioMode%)

	endif

End Sub


Sub InitializeVideoZoneObjects()
	
	m.InitializeZoneCommon(m.bsp.msgPort)
	
    zoneHSM = m
    
    ' create players
    
	' reclaim memory (destroy any leaked video players)
	RunGarbageCollector()

    videoPlayer = CreateObject("roVideoPlayer")
    if type(videoPlayer) <> "roVideoPlayer" then print "videoPlayer creation failed" : stop
    videoPlayer.SetRectangle(zoneHSM.rectangle)
	
    videoInput = CreateObject("roVideoInput")
	
    zoneHSM.videoPlayer = videoPlayer
    zoneHSM.videoInput = videoInput
    zoneHSM.isVideoZone = true
    zoneHSM.videoVolume% = zoneHSM.initialVideoVolume%
    zoneHSM.audioVolume% = zoneHSM.initialAudioVolume%
    
    zoneHSM.videoChannelVolumes = CreateObject("roArray", 6, true)
    zoneHSM.audioChannelVolumes = CreateObject("roArray", 6, true)
    for i% = 0 to 5
        zoneHSM.videoChannelVolumes[i%] = zoneHSM.videoVolume%
        zoneHSM.audioChannelVolumes[i%] = zoneHSM.audioVolume%
    next
    
    ' initialize video player parameters
    videoPlayer.SetPort(zoneHSM.msgPort)
    videoPlayer.SetViewMode(zoneHSM.viewMode%)
    videoPlayer.SetLoopMode(false)

	m.SetAudioOutputAndMode(videoPlayer)

    ' videoPlayer.SetAudioOutput(zoneHSM.audioOutput%)
    ' videoPlayer.SetAudioMode(zoneHSM.audioMode%)
    videoPlayer.MapStereoOutput(zoneHSM.audioMapping%)
    videoPlayer.SetStereoMappingSpan(zoneHSM.audioMappingSpan%)
    videoPlayer.SetVolume(zoneHSM.videoVolume%)

	' Panther only
	zoneHSM.ConfigureAudioResources()

	' Cheetah only
	if m.bsp.sysInfo.deviceFamily$ = "cheetah" then
		if zoneHSM.zOrderFront then
			videoPlayer.ToFront()
		else
			videoPlayer.ToBack()
		endif
	endif

	zoneHSM.videoPlayerAudioSettings = CreateObject("roAssociativeArray")
	zoneHSM.videoPlayerAudioSettings.audioOutput% = zoneHSM.audioOutput%
	zoneHSM.videoPlayerAudioSettings.stereoMapping% = zoneHSM.audioMapping%
	zoneHSM.videoPlayerAudioSettings.audioMappingSpan% = zoneHSM.audioMappingSpan%
	m.bsp.SetAudioVolumeLimits(zoneHSM.videoPlayerAudioSettings) 
	
    ' initialize live video parameters
    videoInput.SetInput(zoneHSM.videoInput$)
    videoInput.SetStandard(zoneHSM.videoStandard$)
    videoInput.SetControlValue("brightness", zoneHSM.brightness%)
    videoInput.SetControlValue("contrast", zoneHSM.contrast%)
    videoInput.SetControlValue("saturation", zoneHSM.saturation%)
    videoInput.SetControlValue("hue", zoneHSM.hue%)

	' initialize tuner parameter
	m.currentChannelIndex% = 0
	m.firstTuneToChannel = true

	m.activeState = m.playlist.firstState
	m.previousStateName$ = m.playlist.firstStateName$
		
End Sub


Sub VideoZoneConstructor()

	activeState = m.InitializeVideoZoneObjects()
	
	m.CreateObjects()

End Sub


Function VideoZoneGetInitialState() As Object

	return m.activeState

End Function


Function STStreamPlayingEventHandler(event As Object, stateData As Object) As Object

    MEDIA_END = 8

    stateData.nextState = invalid
    
	if type(m.stateMachine.audioPlayer) = "roAudioPlayer" or type(m.stateMachine.audioPlayer) = "roAudioPlayerMx" then
		audioPlayer = m.stateMachine.audioPlayer
	else
		audioPlayer = m.stateMachine.videoPlayer
	endif

    if type(event) = "roAssociativeArray" then      ' internal message event

        if IsString(event["EventType"]) then
        
            if event["EventType"] = "ENTRY_SIGNAL" then
            
                m.bsp.diagnostics.PrintDebug(m.id$ + ": entry signal")

				m.ConfigureBPButtons()
				m.usbInputBuffer$ = ""
				m.bsp.ExecuteMediaStateCommands(m.stateMachine, m)

				m.rtspStream = CreateObject("roRtspStream", m.url$)

				if m.mediaType$ = "video" then
					ok = m.stateMachine.videoPlayer.PlayFile({Rtsp: m.rtspStream})
					if ok = 0 then
						m.bsp.diagnostics.PrintDebug("Error playing rtsp file in STStreamPlayingEventHandler: url = " + m.url$)
						videoPlaybackFailure = CreateObject("roAssociativeArray")
						videoPlaybackFailure["EventType"] = "VideoPlaybackFailureEvent"
						m.stateMachine.msgPort.PostMessage(videoPlaybackFailure)
					endif
				else
					ok = audioPlayer.PlayFile({Rtsp: m.rtspStream})
					if ok = 0 then
						m.bsp.diagnostics.PrintDebug("Error playing rtsp file in STStreamPlayingEventHandler: url = " + m.url$)
						audioPlaybackFailure = CreateObject("roAssociativeArray")
						audioPlaybackFailure["EventType"] = "AudioPlaybackFailureEvent"
						m.stateMachine.msgPort.PostMessage(audioPlaybackFailure)
					endif
				endif

				m.bsp.SetTouchRegions(m)

				m.stateMachine.ClearImagePlane()

				m.LaunchTimer()    

				' state logging
				m.bsp.logging.WriteStateLogEntry(m.stateMachine, m.id$, "stream")

				' playback logging
				m.stateMachine.LogPlayStart("stream", m.url$)

                return "HANDLED"

            else if event["EventType"] = "EXIT_SIGNAL" then

                m.bsp.diagnostics.PrintDebug(m.id$ + ": exit signal")
				          
			else if event["EventType"] = "VideoPlaybackFailureEvent" then
        
				if type(m.videoEndEvent) = "roAssociativeArray" then
					return m.ExecuteTransition(m.videoEndEvent, stateData, "")
				endif

			else if event["EventType"] = "AudioPlaybackFailureEvent" then
        
				if type(m.audioEndEvent) = "roAssociativeArray" then
					return m.ExecuteTransition(m.audioEndEvent, stateData, "")
				endif

            else
            
		        return m.MediaItemEventHandler(event, stateData)

            endif
            
        endif
            
	else if type(event) = "roVideoEvent" and event.GetSourceIdentity() = m.stateMachine.videoPlayer.GetIdentity() then            
        if event.GetInt() = MEDIA_END then
            m.bsp.diagnostics.PrintDebug("Video Event" + stri(event.GetInt()))
			m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "mediaEnd", "", "1")
            if type(m.videoEndEvent) = "roAssociativeArray" then
				return m.ExecuteTransition(m.videoEndEvent, stateData, "")
			endif
        endif
	else if type(event) = "roAudioEvent" and event.GetSourceIdentity() = audioPlayer.GetIdentity() then            
        if event.GetInt() = MEDIA_END then
            m.bsp.diagnostics.PrintDebug("Audio Event" + stri(event.GetInt()))
			m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "mediaEnd", "", "1")
            if type(m.audioEndEvent) = "roAssociativeArray" then
				return m.ExecuteTransition(m.audioEndEvent, stateData, "")
			endif
        endif
    else
        return m.MediaItemEventHandler(event, stateData)
	endif

    stateData.nextState = m.superState
    return "SUPER"

End Function


Function STMjpegPlayingEventHandler(event As Object, stateData As Object) As Object
	
    MEDIA_END = 8

    stateData.nextState = invalid
    
    if type(event) = "roAssociativeArray" then      ' internal message event

        if IsString(event["EventType"]) then
        
            if event["EventType"] = "ENTRY_SIGNAL" then
            
                m.bsp.diagnostics.PrintDebug(m.id$ + ": entry signal")

				m.ConfigureBPButtons()
				m.usbInputBuffer$ = ""
				m.bsp.ExecuteMediaStateCommands(m.stateMachine, m)

				if type(m.stateMachine.mjpegUrl) <> "roUrlTransfer" then
					m.stateMachine.mjpegUrl = CreateObject("roUrlTransfer")
				endif

				m.stateMachine.mjpegUrl.SetURL(m.url$)
				m.stateMachine.mjpegUrl.SetProxy("")
			
				if type(m.stateMachine.mjpegMimeStream) <> "roMimeStream" then
					binding% = GetBinding(m.bsp.contentXfersEnabledWired, m.bsp.contentXfersEnabledWireless)
		            m.bsp.diagnostics.PrintDebug("### Binding for mjpegMimeStream is " + stri(binding%))
					ok = m.stateMachine.mjpegUrl.BindToInterface(binding%)
					if not ok then stop
					m.stateMachine.mjpegMimeStream = CreateObject("roMimeStream", m.stateMachine.mjpegUrl)
				endif

				if type(m.stateMachine.mjpegVideoPlayer) <> "roVideoPlayer" then 
					m.stateMachine.mjpegVideoPlayer = CreateObject("roVideoPlayer")
					m.stateMachine.mjpegVideoPlayer.SetRectangle(m.stateMachine.rectangle)
					m.stateMachine.mjpegVideoPlayer.SetPort(m.bsp.msgPort)
				endif

				ok = m.stateMachine.mjpegVideoPlayer.PlayFile({PictureStream: m.stateMachine.mjpegMimeStream, Rotate: m.rotation%})
				m.bsp.SetTouchRegions(m)

				m.stateMachine.ClearImagePlane()

				m.LaunchTimer()    

				' state logging
				m.bsp.logging.WriteStateLogEntry(m.stateMachine, m.id$, "mjpeg")

				' playback logging
				m.stateMachine.LogPlayStart("mjpeg", m.url$)

                return "HANDLED"

            else if event["EventType"] = "EXIT_SIGNAL" then

                m.bsp.diagnostics.PrintDebug(m.id$ + ": exit signal")

				m.stateMachine.mjpegUrl = invalid
				m.stateMachine.mjpegMimeStream = invalid
				m.stateMachine.mjpegVideoPlayer = invalid
				          
'			else if event["EventType"] = "VideoPlaybackFailureEvent" then
        
'				if type(m.videoEndEvent) = "roAssociativeArray" then
'					return m.ExecuteTransition(m.videoEndEvent, stateData, "")
'				endif

            else
            
		        return m.MediaItemEventHandler(event, stateData)

            endif
            
        endif
            
	else if type(event) = "roVideoEvent" and event.GetSourceIdentity() = m.stateMachine.mjpegVideoPlayer.GetIdentity() then            
        if event.GetInt() = MEDIA_END then
            m.bsp.diagnostics.PrintDebug("Video Event" + stri(event.GetInt()))
			m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "mediaEnd", "", "1")
            if type(m.videoEndEvent) = "roAssociativeArray" then
				return m.ExecuteTransition(m.videoEndEvent, stateData, "")
'            else if not(type(m.synchronizeEvents) = "roAssociativeArray" or type(m.internalSynchronizeEvents) = "roAssociativeArray") then
				' looping video - since LaunchVideo is not called, perform logging here.
'			    file$ = m.videoItem.fileName$
'				m.stateMachine.LogPlayStart("video", file$)
			endif
        endif
    else
        return m.MediaItemEventHandler(event, stateData)
	endif

    stateData.nextState = m.superState
    return "SUPER"

End Function



Function STVideoPlayingEventHandler(event As Object, stateData As Object) As Object

    MEDIA_END = 8
	VIDEO_TIME_CODE = 12
	
    stateData.nextState = invalid
    
    if type(event) = "roAssociativeArray" then      ' internal message event

        if IsString(event["EventType"]) then
        
            if event["EventType"] = "ENTRY_SIGNAL" then
            
                m.bsp.diagnostics.PrintDebug(m.id$ + ": entry signal")

				m.LaunchVideo("video")

                return "HANDLED"

            else if event["EventType"] = "EXIT_SIGNAL" then

                m.bsp.diagnostics.PrintDebug(m.id$ + ": exit signal")
            
			else if event["EventType"] = "VideoPlaybackFailureEvent" then
        
				if type(m.videoEndEvent) = "roAssociativeArray" then
					return m.ExecuteTransition(m.videoEndEvent, stateData, "")
				endif

            else
            
		        return m.MediaItemEventHandler(event, stateData)

            endif
            
        endif

	else if type(event) = "roVideoEvent" and event.GetSourceIdentity() = m.stateMachine.videoPlayer.GetIdentity() then
        if event.GetInt() = MEDIA_END then
            m.bsp.diagnostics.PrintDebug("Video Event" + stri(event.GetInt()))
			m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "mediaEnd", "", "1")
            if type(m.videoEndEvent) = "roAssociativeArray" then
				return m.ExecuteTransition(m.videoEndEvent, stateData, "")
            else if not(type(m.synchronizeEvents) = "roAssociativeArray" or type(m.internalSynchronizeEvents) = "roAssociativeArray") then
				' looping video - since LaunchVideo is not called, perform logging here.
			    file$ = m.videoItem.fileName$
				m.stateMachine.LogPlayStart("video", file$)
			endif
        else if event.GetInt() = VIDEO_TIME_CODE then
			videoTimeCodeIndex$ = str(event.GetData())
			m.bsp.diagnostics.PrintDebug("Video TimeCode Event " + videoTimeCodeIndex$)
            if type(m.videoTimeCodeEvents) = "roAssociativeArray" then
                videoTimeCodeEvent = m.videoTimeCodeEvents[videoTimeCodeIndex$]
                if type(videoTimeCodeEvent) = "roAssociativeArray" then
					m.bsp.ExecuteTransitionCommands(m.stateMachine, videoTimeCodeEvent)
					m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "videoTimeCode", "", "1")
					return "HANDLED"      
                endif
			m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "videoTimeCode", "", "0")
            endif
        endif
    else
        return m.MediaItemEventHandler(event, stateData)
	endif

    stateData.nextState = m.superState
    return "SUPER"

End Function


Sub SetVideoTimeCodeEvents()

    m.stateMachine.videoPlayer.ClearEvents()

    if type(m.videoTimeCodeEvents) = "roAssociativeArray" then
        for each eventNum in m.videoTimeCodeEvents
            m.AddVideoTimeCodeEvent(m.videoTimeCodeEvents[eventNum].timeInMS%, int(val(eventNum)))                    
        next
    endif
    
End Sub


Sub AddVideoTimeCodeEvent(timeInMS% As Integer, eventNum% As Integer)

    if type(m.stateMachine.videoPlayer) = "roVideoPlayer" then
        m.stateMachine.videoPlayer.AddEvent(eventNum%, timeInMS%)
    endif
        
End Sub

'endregion

'region Video or Images State Machine
' *************************************************
'
' VideoOrImages State Machine
'
' *************************************************
Function newVideoOrImagesZoneHSM(bsp As Object, zoneXML As Object) As Object

    zoneHSM = newVideoZoneHSM(bsp, zoneXML)
	zoneHSM.ConstructorHandler = VideoOrImagesZoneConstructor
	zoneHSM.InitialPseudostateHandler = VideoOrImagesZoneGetInitialState
    
    zoneHSM.imageMode% = GetImageModeValue(zoneXML.zoneSpecificParameters.imageMode.GetText())

	zoneHSM.numImageItems% = 0

    return zoneHSM
    
End Function


Sub LoadImageBuffers()

	stateTable = m.stateTable
    for each stateName in stateTable
        state = stateTable[stateName]
        if type(state.imageItem) = "roAssociativeArray" then
			imageItem = state.imageItem
			if imageItem.useImageBuffer then
				m.AddImageBufferItem(imageItem.fileName$)
			endif
		else if state.type$ = "interactiveMenuItem" then
			
			if state.backgroundImage$ <> "" and state.backgroundImageUseImageBuffer then
				m.AddImageBufferItem(state.backgroundImage$)
			endif
					
			if type(state.interactiveMenuItems) = "roArray" then
				for each interactiveMenuItem in state.interactiveMenuItems
					if interactiveMenuItem.selectedImageUseImageBuffer then
						m.AddImageBufferItem(interactiveMenuItem.selectedImage$)
					endif
					if interactiveMenuItem.selectedImageUseImageBuffer then
						m.AddImageBufferItem(interactiveMenuItem.unselectedImage$)
					endif
					if interactiveMenuItem.targetType$ = "mediaFile" and IsString(interactiveMenuItem.targetImageFile$) and interactiveMenuItem.targetImageFile$ <> "" then
						m.AddImageBufferItem(interactiveMenuItem.targetImageFile$)
					endif
				next
			endif
		endif
	next

End Sub


Sub AddImageBufferItem(fileName$ As String)

    filePath$ = GetPoolFilePath(m.bsp.syncPoolFiles, fileName$)
    if type(m.bsp.imageBuffers) <> "roAssociativeArray" then
		m.bsp.imageBuffers = CreateObject("roAssociativeArray")
	endif
	if not m.bsp.imageBuffers.DoesExist(filePath$) then
		imageBuffer = CreateObject("roImageBuffer", 0, filePath$)
		m.bsp.imageBuffers.AddReplace(filePath$, imageBuffer)
	endif
	
End Sub


Sub ClearImageBuffers()

    if type(m.imageBuffers) = "roAssociativeArray" then
		for each imageBuffer in m.imageBuffers
			imageBuffer = invalid
		next
		m.imageBuffers = invalid
    endif

End Sub


Sub VideoOrImagesZoneConstructor()

	m.InitializeVideoZoneObjects()
    
    zoneHSM = m
    
    ' create players
	if zoneHSM.numImageItems% > 0 then

		imagePlayer = CreateObject("roImageWidget", zoneHSM.rectangle)
	    
		zoneHSM.imagePlayer = imagePlayer
	    
		' initialize image player parameters
		imagePlayer.SetDefaultMode(zoneHSM.imageMode%)

		m.LoadImageBuffers()

	else
	
		zoneHSM.imagePlayer = invalid
		
	endif
    
    zoneHSM.audioVolume% = zoneHSM.initialAudioVolume%
    
	audioInput = CreateObject("roAudioInput", m.bsp.sign.audioInSampleRate%)
	if type(audioInput) = "roAudioInput" then
		zoneHSM.audioInput = audioInput
	endif
	
	zoneHSM.audioPlayerAudioSettings = CreateObject("roAssociativeArray")
	zoneHSM.audioPlayerAudioSettings.audioOutput% = zoneHSM.audioOutput%
	zoneHSM.audioPlayerAudioSettings.stereoMapping% = zoneHSM.audioMapping%
	m.bsp.SetAudioVolumeLimits(zoneHSM.audioPlayerAudioSettings) 
	
	m.CreateObjects()

End Sub


Function VideoOrImagesZoneGetInitialState() As Object
		
	return m.activeState

End Function


Function STPlayFileEventHandler(event As Object, stateData As Object) As Object

    MEDIA_END = 8

    stateData.nextState = invalid

    if type(event) = "roAssociativeArray" then      ' internal message event

        if IsString(event["EventType"]) then
        
            if event["EventType"] = "ENTRY_SIGNAL" then
            
                m.bsp.diagnostics.PrintDebug(m.id$ + ": entry signal")

				m.bsp.diagnostics.PrintDebug(m.id$ + ": payload is " + m.payload$)

				if not m.filesTable.DoesExist(m.payload$) then
					m.bsp.diagnostics.PrintDebug(m.id$ + ": no file associated with payload")
					m.ConfigureBPButtons()
					m.usbInputBuffer$ = ""
					m.bsp.ExecuteMediaStateCommands(m.stateMachine, m)
					m.LaunchTimer()    
					m.bsp.SetTouchRegions(m)
				else
					fileTableEntry = m.filesTable.Lookup(m.payload$)
					fileName$ = fileTableEntry.fileName$
					fileType$ = fileTableEntry.fileType$
					m.imageItem = invalid
					m.videoItem = invalid
					m.audioItem = invalid
					if fileType$ = "image" then
						m.imageItem = CreateObject("roAssociativeArray")
						m.imageItem.fileName$ = fileName$
						m.imageItem.slideTransition% = m.slideTransition%
						m.imageItem.useImageBuffer = false
						m.DisplayImage("playFile")
					else if fileType$ = "video" then
						m.videoItem = CreateObject("roAssociativeArray")
						m.videoItem.fileName$ = fileName$
						m.videoItem.probeData = fileTableEntry.probeData
						m.videoItem.videoDisplayMode% = fileTableEntry.videoDisplayMode%
						m.LaunchVideo("playFile")
					else if fileType$ = "audio" then
						m.audioItem = CreateObject("roAssociativeArray")
						m.audioItem.fileName$ = fileName$
						m.audioItem.probeData = fileTableEntry.probeData
						m.LaunchAudio("playFile")
					endif
				endif

				return "HANDLED"

            else if event["EventType"] = "EXIT_SIGNAL" then

                m.bsp.diagnostics.PrintDebug(m.id$ + ": exit signal")
					
				return "HANDLED"
            
            endif
            
        endif

    else if type(m.videoItem) = "roAssociativeArray" and type(event) = "roVideoEvent" and event.GetSourceIdentity() = m.stateMachine.videoPlayer.GetIdentity() then
        if event.GetInt() = MEDIA_END then
            m.bsp.diagnostics.PrintDebug("Video Event" + stri(event.GetInt()))
			m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "mediaEnd", "", "1")
            if type(m.videoEndEvent) = "roAssociativeArray" then
				return m.ExecuteTransition(m.videoEndEvent, stateData, "")
            endif
        endif

    else if type(m.audioItem)="roAssociativeArray" and IsAudioEvent(m.stateMachine, event) then
        if event.GetInt() = MEDIA_END then
            m.bsp.diagnostics.PrintDebug("Audio Event" + stri(event.GetInt()))
			m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "mediaEnd", "", "1")
            if type(m.audioEndEvent) = "roAssociativeArray" then
				return m.ExecuteTransition(m.audioEndEvent, stateData, "")
            endif
        endif

	endif

	return m.MediaItemEventHandler(event, stateData)	

End Function


' this code explicitly does not catch roAudioEventMx events - those are handled elsewhere.
Function IsAudioEvent(stateMachine As Object, event As Object) As Boolean

	return (type(stateMachine.audioPlayer)="roAudioPlayer" and type(event) = "roAudioEvent" and event.GetSourceIdentity() = stateMachine.audioPlayer.GetIdentity()) or (type(stateMachine.videoPlayer)="roVideoPlayer" and type(event) = "roVideoEvent" and event.GetSourceIdentity() = stateMachine.videoPlayer.GetIdentity())

End Function


Function IsAudioPlayer(audioPlayer As Object) As Boolean

	return type(audioPlayer) = "roAudioPlayer" or type(audioPlayer) = "roAudioPlayerMx"

End Function


Sub ConfigureIntraStateEventHandlerButton(navigation As Object)

	if type(navigation) = "roAssociativeArray" then
		if type(navigation.bpUserEventButtonPanelIndex$) = "roString" and type(navigation.bpUserEventButtonNumber$) = "roString" then
			bpEvent = { }
			bpEvent.buttonPanelIndex% = int(val(navigation.bpUserEventButtonPanelIndex$))
			bpEvent.buttonNumber$ = navigation.bpUserEventButtonNumber$
			bpEvent.configuration$ = "press"
			m.bsp.ConfigureBPButton(bpEvent.buttonPanelIndex%, bpEvent.buttonNumber$, bpEvent)
		endif
	endif

End Sub


Function STDisplayingMediaListItemEventHandler(event As Object, stateData As Object) As Object

    MEDIA_START = 3
    MEDIA_END = 8
    MEDIA_ERROR = 16

	VIDEO_TIME_CODE = 12

    stateData.nextState = invalid

    if type(event) = "roAssociativeArray" then      ' internal message event

        if IsString(event["EventType"]) then
        
            if event["EventType"] = "ENTRY_SIGNAL" then
            
                m.bsp.diagnostics.PrintDebug(m.id$ + ": entry signal")

				if type(m.bsp.mediaListInactivity) = "roAssociativeArray" then

					if type(m.bsp.mediaListInactivity.timer) = "roTimer" then
						m.bsp.mediaListInactivity.timer.Stop()
					else
						m.bsp.mediaListInactivity.timer = CreateObject("roTimer")
						m.bsp.mediaListInactivity.timer.SetPort(m.bsp.msgPort)
					endif

				endif

				m.ConfigureIntraStateEventHandlerButton(m.nextNavigation)
				m.ConfigureIntraStateEventHandlerButton(m.previousNavigation)

				' reset playback index if appropriate
				if m.playFromBeginning then
					m.playbackIndex% = 0
				endif

				' reshuffle media list if appropriate
				if m.playbackIndex% = 0 and m.shuffle then
	
					randomNumbers = CreateObject("roArray", m.numItems%, true)
					for each item in m.items
						randomNumbers.push(rnd(10000))
					next
		
					numItemsToSort% = m.numItems%
					
					for i% = numItemsToSort% - 1 to 1 step -1
						for j% = 0 to i%-1
							index0 = m.playbackIndices[j%]
							value0 = randomNumbers[index0]
							index1 = m.playbackIndices[j%+1]
							value1 = randomNumbers[index1]
							if value0 > value1 then
								k% = m.playbackIndices[j%]
								m.playbackIndices[j%] = m.playbackIndices[j%+1]
								m.playbackIndices[j%+1] = k%
							endif
						next
					next
					
				endif

				m.AdvanceMediaListPlayback(true)
				
				return "HANDLED"

			else if event["EventType"] = "VideoPlaybackFailureEvent" then
        
				if type(m.videoEndEvent) = "roAssociativeArray" then
					return m.ExecuteTransition(m.videoEndEvent, stateData, "")
				endif

			else if event["EventType"] = "AudioPlaybackFailureEvent" then
        
				if type(m.audioEndEvent) = "roAssociativeArray" then
					return m.ExecuteTransition(m.audioEndEvent, stateData, "")
				endif

            else if event["EventType"] = "EXIT_SIGNAL" then

                m.bsp.diagnostics.PrintDebug(m.id$ + ": exit signal")
	
				m.StartInactivityTimer()
				
				return "HANDLED"
            
            endif
            
        endif
            
    else if m.mediaType$ = "video" and type(event) = "roVideoEvent" and event.GetSourceIdentity() = m.stateMachine.videoPlayer.GetIdentity() then
        if event.GetInt() = MEDIA_END then
            m.bsp.diagnostics.PrintDebug("Video Event" + stri(event.GetInt()))
			m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "mediaEnd", "", "1")
			if m.advanceOnMediaEnd then
				if not(m.playbackIndex% = 0 and type(m.videoEndEvent) = "roAssociativeArray") then
					m.AdvanceMediaListPlayback(true)
					return "HANDLED"
				endif
			endif
            if type(m.videoEndEvent) = "roAssociativeArray" then
				return m.ExecuteTransition(m.videoEndEvent, stateData, "")
            endif
        else if event.GetInt() = VIDEO_TIME_CODE then
			videoTimeCodeIndex$ = str(event.GetData())
			m.bsp.diagnostics.PrintDebug("Video TimeCode Event " + videoTimeCodeIndex$)
            if type(m.videoTimeCodeEvents) = "roAssociativeArray" then
                videoTimeCodeEvent = m.videoTimeCodeEvents[videoTimeCodeIndex$]
                if type(videoTimeCodeEvent) = "roAssociativeArray" then
					m.bsp.ExecuteTransitionCommands(m.stateMachine, videoTimeCodeEvent)
					m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "videoTimeCode", "", "1")
					return "HANDLED"      
                endif
            endif
			m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "videoTimeCode", "", "0")
        endif
	else if m.mediaType$ = "audio" and m.stateMachine.type$ = "EnhancedAudio" and type(event) = "roAudioEventMx" then
        if event.GetInt() = MEDIA_START then
	        if event.GetSourceIdentity() = m.stateMachine.audioPlayer.GetIdentity() then

				' index of track that just started playing
				currentTrackIndex% = int(val(event.GetUserData()))

				' get index of track to queue
				m.playbackIndex% = currentTrackIndex% + 1
				if m.playbackIndex% >= m.numItems% then
					m.playbackIndex% = 0
				endif

				m.audioItem = m.items[m.playbackIndices[m.playbackIndex%]]
				m.LaunchMixerAudio(m.playbackIndex%, false)

				' at this point, m.playbackIndex% points to both the item that is queued as well as the next item to play - the concept of
				' "next item to play" is needed for NextNavigation, BackNavigation, and re-entering the state

'				m.AdvanceMediaListPlayback(false)
				return "HANDLED"
			endif
		endif
    else if m.mediaType$ = "audio" and m.stateMachine.type$ <> "EnhancedAudio" and IsAudioEvent(m.stateMachine, event) then
        if event.GetInt() = MEDIA_END then
            m.bsp.diagnostics.PrintDebug("Audio Event" + stri(event.GetInt()))
			m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "mediaEnd", "", "1")
			if m.advanceOnMediaEnd then
				if not(m.playbackIndex% = 0 and type(m.audioEndEvent) = "roAssociativeArray") then
					m.AdvanceMediaListPlayback(true)
					return "HANDLED"
				endif
			endif
            if type(m.audioEndEvent) = "roAssociativeArray" then
				return m.ExecuteTransition(m.audioEndEvent, stateData, "")
            endif
        endif
	else if type(event) = "roTimerEvent" then
		if m.advanceOnImageTimeout then

			if type(m.advanceOnImageTimeoutTimer) = "roTimer" and event.GetSourceIdentity() = m.advanceOnImageTimeoutTimer.GetIdentity() then
				if m.playbackIndex% <> 0 or type(m.mstimeoutEvent) <> "roAssociativeArray" then
					m.AdvanceMediaListPlayback(true)
					m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "timeout", "", "1")
					return "HANDLED"
				endif
			endif

			if m.playbackIndex% = 0 and type(m.mstimeoutEvent) = "roAssociativeArray" and type(m.advanceOnImageTimeoutTimer) = "roTimer" and event.GetSourceIdentity() = m.advanceOnImageTimeoutTimer.GetIdentity() then
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "timeout", "", "1")
				return m.ExecuteTransition(m.mstimeoutEvent, stateData, "")
			endif

			return "HANDLED"
		endif
		m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "timeout", "", "0")
	endif

	if type(m.nextNavigation) = "roAssociativeArray" then
		advance = m.HandleIntraStateEvent(event, m.nextNavigation)
		if advance then
			m.AdvanceMediaListPlayback(true)
			return "HANDLED"
		endif
	endif
	
	if type(m.previousNavigation) = "roAssociativeArray" then
		retreat = m.HandleIntraStateEvent(event, m.previousNavigation)
		if retreat then
			m.RetreatMediaListPlayback(true)
			return "HANDLED"
		endif
	endif    
    
	return m.MediaItemEventHandler(event, stateData)	

End Function


Function HandleIntraStateEvent(event As Object, navigation As Object) As Boolean

    if type(event) = "roAssociativeArray" and IsString(event["EventType"]) and event["EventType"] = "BPControlDown" and IsString(navigation.bpUserEventButtonNumber$) then
		bpIndex$ = event["ButtonPanelIndex"]
		bpNum$ = event["ButtonNumber"]
		m.bsp.diagnostics.PrintDebug("BP Press, button number " + bpNum$ + ", button index " + bpIndex$)
		if navigation.bpUserEventButtonNumber$ = bpNum$ and navigation.bpUserEventButtonPanelIndex$ = bpIndex$ then
			m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "bpDown", bpIndex$ + " " + bpNum$, "1")
			return true
		endif
    endif
    
    if type(event) = "roControlDown" and stri(event.GetSourceIdentity()) = stri(m.bsp.controlPort.GetIdentity()) and IsString(navigation.gpioUserEvent$) then
        gpioNum$ = StripLeadingSpaces(str(event.GetInt()))
        m.bsp.diagnostics.PrintDebug("Button Press" + gpioNum$)
        if navigation.gpioUserEvent$ = gpioNum$ then
			m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "gpioButton", gpioNum$, "1")
			return true
		endif
    endif
    
    if type(event) = "roDatagramEvent" and IsString(navigation.udpUserEvent$) then
		udpEvent$ = event.GetString()
		m.bsp.diagnostics.PrintDebug("UDP Event" + udpEvent$)

        if navigation.udpUserEvent$ = udpEvent$ or navigation.udpEvent$ = "<any>" then
			m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "udp", udpEvent$, "1")
			return true
		endif
	endif

	if type(event) = "roKeyboardPress" and IsString(navigation.keyboardUserEvent$) then
		keyboardChar$ = chr(event.GetInt())
		m.bsp.diagnostics.PrintDebug("Keyboard Press" + keyboardChar$)
		
		' if keyboard input is non printable character, convert it to the special code
		keyboardCode$ = m.bsp.GetNonPrintableKeyboardCode(event.GetInt())
		if keyboardCode$ <> "" then
			keyboardChar$ = keyboardCode$
		endif

        if navigation.keyboardUserEvent$ = keyboardChar$ or navigation.keyboardUserEvent$ = "<any>" then
			m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "keyboard", keyboardChar$, "1")
			return true
		endif
    endif   

    if type(event) = "roStreamLineEvent" and IsString(navigation.serialUserEventPort$) and IsString(navigation.serialUserEventSerialEvent$) then

        port$ = event.GetUserData()
        serialEvent$ = event.GetString()

	    m.bsp.diagnostics.PrintDebug("Serial Line Event " + event.GetString())

		if port$ = navigation.serialUserEventPort$ and (serialEvent$ = navigation.serialUserEventSerialEvent$ or navigation.serialUserEventSerialEvent$ = "<*>") then
			m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "serial", serialEvent$, "1")
			return true
		endif

	endif
	         
    return false
    
End Function


Sub LaunchMediaListPlaybackItem(playImmediate As Boolean)

	' get current media item and launch playback
	item = m.items[m.playbackIndices[m.playbackIndex%]]

	if m.mediaType$ = "image" then
	
		m.imageItem = item
		m.DisplayImage("imageList")

		' if advancing on image timeout, set the timer
		if type(m.advanceOnImageTimeoutTimer) = "roTimer" then
			m.advanceOnImageTimeoutTimer.Stop()
		endif

		if m.advanceOnImageTimeout then
			if type(m.advanceOnImageTimeoutTimer) <> "roTimer" then
				m.advanceOnImageTimeoutTimer = CreateObject("roTimer")
				m.advanceOnImageTimeoutTimer.SetPort(m.stateMachine.msgPort)
			endif
		    systemTime = CreateObject("roSystemTime")
			newTimeout = systemTime.GetLocalDateTime()
			newTimeout.AddMilliseconds(m.imageTimeout)
			m.advanceOnImageTimeoutTimer.SetDateTime(newTimeout)
			m.advanceOnImageTimeoutTimer.Start()
		endif
	
	else if m.mediaType$ = "video" then
	
		m.videoItem = item
		m.LaunchVideo("videoList")
	
	else if m.mediaType$ = "audio" then
	
		m.audioItem = item

		if m.stateMachine.type$ = "EnhancedAudio" then
			m.LaunchMixerAudio(m.playbackIndex%, playImmediate)
		else		
			m.LaunchAudio("audioList")
		endif

	endif

End Sub


Sub AdvanceMediaListPlayback(playImmediate As Boolean)

	m.LaunchMediaListPlaybackItem(playImmediate)
	
	m.playbackIndex% = m.playbackIndex% + 1
	if m.playbackIndex% >= m.numItems% then
		m.playbackIndex% = 0
	endif
				
End Sub


Sub RetreatMediaListPlayback(playImmediate As Boolean)
	
	' index currently points to 'next' track - need to retreat by 2 to get to previous track
    for i% = 0 to 1
		m.playbackIndex% = m.playbackIndex% - 1
		if m.playbackIndex% < 0 then
			m.playbackIndex% = m.numItems% - 1
		endif
	next

	m.LaunchMediaListPlaybackItem(playImmediate)
	
	m.playbackIndex% = m.playbackIndex% + 1
	if m.playbackIndex% >= m.numItems% then
		m.playbackIndex% = 0
	endif
				
End Sub


Sub StartInactivityTimer()

	if m.bsp.inactivityTimeout then
		if type(m.bsp.mediaListInactivity) = "roAssociativeArray" then
			if type(m.bsp.mediaListInactivity.timer) = "roTimer" then
				newTimeout = m.bsp.systemTime.GetLocalDateTime()
				newTimeout.AddSeconds(m.bsp.inactivityTime%)
				m.bsp.mediaListInactivity.timer.Stop()
				m.bsp.mediaListInactivity.timer.SetDateTime(newTimeout)
				m.bsp.mediaListInactivity.timer.SetPort(m.bsp.msgPort)
				m.bsp.mediaListInactivity.timer.Start()
			endif
		endif
	endif
	
End Sub


Sub ConfigureBPButtons()

	for buttonPanelIndex% = 0 to 2
		bpEvents = m.bpEvents[buttonPanelIndex%]
		for each buttonNumber in bpEvents
			bpEvent = bpEvents[buttonNumber]
			m.bsp.ConfigureBPButton(buttonPanelIndex%, buttonNumber, bpEvent)
		next
	next
	
End Sub


Sub LaunchVideo(stateType$ As String)

	m.ConfigureBPButtons()
	
'	if type(m.stateMachine.audioPlayer) = "roAudioPlayer" then
'		m.stateMachine.audioPlayer.Stop()
'	endif

	m.usbInputBuffer$ = ""

	' set video mode before executing commands - required order for working around LG (maybe others) bugs getting back to 2-D mode
	videoMode = CreateObject("roVideoMode")
	videoMode.Set3dMode(m.videoItem.videoDisplayMode%)
	videoMode = invalid

    loopMode% = 1
	if type(m.videoEndEvent) = "roAssociativeArray" or type(m.synchronizeEvents) = "roAssociativeArray" or type(m.internalSynchronizeEvents) = "roAssociativeArray" then loopMode% = 0
    
    m.stateMachine.videoPlayer.SetLoopMode(loopMode%)

    file$ = m.videoItem.fileName$
    
	' determine whether or not a preload has been performed
	preloaded = false
	if type(m.stateMachine.preloadState) = "roAssociativeArray" then
		if m.stateMachine.preloadedStateName$ = m.name$ then
			preloaded = true
		endif
	endif

	m.stateMachine.videoPlayer.EnableSafeRegionTrimming(false)

	if not preloaded then
		m.stateMachine.videoPlayer.Stop()
	endif
	
    m.SetVideoTimeCodeEvents()

	m.bsp.ExecuteMediaStateCommands(m.stateMachine, m)

	if preloaded then
		ok = m.stateMachine.videoPlayer.Play()
		if ok=0 print "Error Playing (supposedly) Preloaded File: " ; file$ : stop
		m.stateMachine.preloadState = invalid
		m.stateMachine.preloadedStateName$ = ""

		m.bsp.diagnostics.PrintDebug("LaunchVideo: play preloaded file " + file$ + ", loopMode = " + str(loopMode%))

	else   

		filePath$ = GetPoolFilePath(m.bsp.syncPoolFiles, file$)

		aa = { }
		aa.AddReplace("Filename", filePath$)
		
		if type(m.videoItem.probeData) = "roString" then
			m.bsp.diagnostics.PrintDebug("LaunchVideo: probeData = " + m.videoItem.probeData)
			aa.AddReplace("ProbeString", m.videoItem.probeData)
		endif

		ok = m.stateMachine.videoPlayer.PlayFile(aa)
		if ok = 0 then
		
			m.bsp.diagnostics.PrintDebug("Error playing file in LaunchVideo: " + file$ + ", " + filePath$)

            videoPlaybackFailure = CreateObject("roAssociativeArray")
            videoPlaybackFailure["EventType"] = "VideoPlaybackFailureEvent"
            m.stateMachine.msgPort.PostMessage(videoPlaybackFailure)

		endif
		
	endif
    
    m.bsp.SetTouchRegions(m)

	m.stateMachine.ClearImagePlane()

    m.LaunchTimer()    

	if type(m.videoItem.userVariable) = "roAssociativeArray" then
		m.videoItem.userVariable.Increment()
	endif

	' state logging
	m.bsp.logging.WriteStateLogEntry(m.stateMachine, m.id$, stateType$)

	' playback logging
	m.stateMachine.LogPlayStart("video", file$)

End Sub


Sub DisplayImage(stateType$ As String)

	m.ConfigureBPButtons()
	
	m.usbInputBuffer$ = ""

	m.bsp.ExecuteMediaStateCommands(m.stateMachine, m)

    file$ = m.imageItem.fileName$

    m.stateMachine.imagePlayer.SetDefaultTransition(m.imageItem.slideTransition%)
	
	filePath$ = GetPoolFilePath(m.bsp.syncPoolFiles, file$)

    if m.imageItem.useImageBuffer and type(m.bsp.imageBuffers) = "roAssociativeArray" and m.bsp.imageBuffers.DoesExist(filePath$) then
		m.bsp.diagnostics.PrintDebug("Use imageBuffer for " + file$ + " in DisplayImage: ")
		imageBuffer = m.bsp.imageBuffers.Lookup(filePath$)
		m.stateMachine.ClearImagePlane()
		m.stateMachine.imagePlayer.DisplayBuffer(imageBuffer, 0, 0)
    else

'		m.stateMachine.canvasWidget = invalid

		' determine whether or not a preload has been performed
		preloaded = false
		if type(m.stateMachine.preloadState) = "roAssociativeArray" then
			if m.stateMachine.preloadedStateName$ = m.name$
				preloaded = true
				m.bsp.diagnostics.PrintDebug("Use preloaded file " + file$ + " in DisplayImage: ")
			endif
		endif

		if not preloaded then
			ok = m.stateMachine.imagePlayer.PreloadFile(filePath$)
			if ok = 0 then
				m.bsp.diagnostics.PrintDebug("Error preloading file in DisplayImage: " + file$ + ", " + filePath$)
			else
				m.bsp.diagnostics.PrintDebug("Preloaded file in DisplayImage: " + file$)
			endif   
		endif
	    
		m.bsp.diagnostics.PrintDebug("DisplayPreload in DisplayImage: " + file$)
		ok = m.stateMachine.imagePlayer.DisplayPreload()
		if ok = 0 then
			m.bsp.diagnostics.PrintDebug("Error in DisplayPreload in DisplayImage: " + file$ + ", " + filePath$)
		endif

    endif

	m.stateMachine.ShowImageWidget()

	m.stateMachine.preloadState = 0
	m.stateMachine.preloadedStateName$ = ""
                    
    if type(m.stateMachine.videoPlayer) = "roVideoPlayer" then
        m.stateMachine.videoPlayer.StopClear()
    endif

    m.LaunchTimer()    

    m.bsp.SetTouchRegions(m)

	if type(m.imageItem.userVariable) = "roAssociativeArray" then
		m.imageItem.userVariable.Increment()
	endif
    
	' state logging
	m.bsp.logging.WriteStateLogEntry(m.stateMachine, m.id$, stateType$)

	' playback logging
	m.stateMachine.LogPlayStart("image", file$)

End Sub


Sub LaunchAudio(stateType$ As String)

	m.ConfigureBPButtons()
	
	m.usbInputBuffer$ = ""

    if type(m.stateMachine.videoPlayer) = "roVideoPlayer" then
        m.stateMachine.videoPlayer.StopClear()
    endif
    
    loopMode% = 1
    if type(m.audioEndEvent) = "roAssociativeArray" then loopMode% = 0
    
	if type(m.stateMachine.audioPlayer) = "roAudioPlayer" then
		player = m.stateMachine.audioPlayer
	else
		player = m.stateMachine.videoPlayer
	endif

    player.SetLoopMode(loopMode%)

	player.Stop()

	m.bsp.ExecuteMediaStateCommands(m.stateMachine, m)

    file$ = m.audioItem.fileName$
    filePath$ = GetPoolFilePath(m.bsp.syncPoolFiles, file$)

	aa = { }
	aa.AddReplace("Filename", filePath$)
		
	if type(m.audioItem.probeData) = "roString" then
		m.bsp.diagnostics.PrintDebug("LaunchAudio: probeData = " + m.audioItem.probeData)
		aa.AddReplace("ProbeString", m.audioItem.probeData)
	endif

	ok = player.PlayFile(aa)

	if ok = 0 then
		m.bsp.diagnostics.PrintDebug("Error playing audio file: " + file$ + ", " + filePath$)

        audioPlaybackFailure = CreateObject("roAssociativeArray")
        audioPlaybackFailure["EventType"] = "AudioPlaybackFailureEvent"
        m.stateMachine.msgPort.PostMessage(audioPlaybackFailure)
	endif

    m.bsp.SetTouchRegions(m)

	m.stateMachine.ClearImagePlane()

    m.LaunchTimer()    

	if type(m.audioItem.userVariable) = "roAssociativeArray" then
		m.audioItem.userVariable.Increment()
	endif
    
	' state logging
	m.bsp.logging.WriteStateLogEntry(m.stateMachine, m.id$, stateType$)

	' playback logging
	m.stateMachine.LogPlayStart("audio", file$)

End Sub


Function STAudioInPlayingEventHandler(event As Object, stateData As Object) As Object

    stateData.nextState = invalid
    
    if type(event) = "roAssociativeArray" then      ' internal message event

        if IsString(event["EventType"]) then
        
            if event["EventType"] = "ENTRY_SIGNAL" then
            
                m.bsp.diagnostics.PrintDebug(m.id$ + ": entry signal")

				m.ConfigureBPButtons()

				m.usbInputBuffer$ = ""

				videoZone = m.bsp.GetVideoZone(m.stateMachine)
				if type(videoZone) = "roAssociativeArray" then
					videoZone.videoPlayer.StopClear()
				endif
    
				m.bsp.ExecuteMediaStateCommands(m.stateMachine, m)

				m.stateMachine.StopSignChannelInZone()

				file$ = m.imageFileName$

				if file$ <> "" then
				
					m.stateMachine.imagePlayer.SetDefaultTransition(0)
		
					filePath$ = GetPoolFilePath(m.bsp.syncPoolFiles, file$)

					ok = m.stateMachine.imagePlayer.PreloadFile(filePath$)
					if ok = 0 then
						m.bsp.diagnostics.PrintDebug("Error preloading file in STAudioInPlayingEventHandler: " + file$ + ", " + filePath$)
					else
						m.bsp.diagnostics.PrintDebug("Preloaded file in STAudioInPlayingEventHandler: " + file$)
					endif   
	    
					m.bsp.diagnostics.PrintDebug("DisplayPreload in STAudioInPlayingEventHandler: " + file$)
					ok = m.stateMachine.imagePlayer.DisplayPreload()
					if ok = 0 then
						m.bsp.diagnostics.PrintDebug("Error in DisplayPreload in STAudioInPlayingEventHandler: " + file$ + ", " + filePath$)
					endif

					m.stateMachine.ShowImageWidget()

				endif					

				if type(m.stateMachine.audioPlayer) = "roAudioPlayer" then
					player = m.stateMachine.audioPlayer
				else
					player = m.stateMachine.videoPlayer
				endif

				player.PlayFile(m.stateMachine.audioInput)

				m.LaunchTimer()    

		        m.bsp.SetTouchRegions(m)

				if file$ <> "" and type(m.imageUserVariable) = "roAssociativeArray" then
					m.imageUserVariable.Increment()
				endif
								
				' state logging
				m.bsp.logging.WriteStateLogEntry(m.stateMachine, m.id$, "audioIn")

				' playback logging
				m.stateMachine.LogPlayStart("audioIn", "")

				return "HANDLED"
				
            else if event["EventType"] = "EXIT_SIGNAL" then

                m.bsp.diagnostics.PrintDebug(m.id$ + ": exit signal")
                
				if type(m.stateMachine.audioPlayer) = "roAudioPlayer" then
					player = m.stateMachine.audioPlayer
				else
					player = m.stateMachine.videoPlayer
				endif

				player.Stop()
                
            else
            
		        return m.MediaItemEventHandler(event, stateData)

			endif
			
		endif
		
    else
        return m.MediaItemEventHandler(event, stateData)
	endif

    stateData.nextState = m.superState
    return "SUPER"

End Function


Function STEventHandlerEventHandler(event As Object, stateData As Object) As Object

    stateData.nextState = invalid
    
    if type(event) = "roAssociativeArray" then      ' internal message event

        if IsString(event["EventType"]) then
        
            if event["EventType"] = "ENTRY_SIGNAL" then
            
                m.bsp.diagnostics.PrintDebug(m.id$ + ": entry signal")

				m.ConfigureBPButtons()

				m.usbInputBuffer$ = ""

				m.bsp.ExecuteMediaStateCommands(m.stateMachine, m)
    
				if m.stopPlayback then

					if type(m.stateMachine.videoPlayer) = "roVideoPlayer" then
						m.stateMachine.videoPlayer.StopClear()
					endif

					m.stateMachine.ClearImagePlane()

					if IsAudioPlayer(m.stateMachine.audioPlayer) then
						m.stateMachine.audioPlayer.Stop()
					endif

					m.stateMachine.StopSignChannelInZone()
	
				endif

				m.LaunchTimer()    

		        m.bsp.SetTouchRegions(m)

				' state logging
				m.bsp.logging.WriteStateLogEntry(m.stateMachine, m.id$, "eventHandler")

				' playback logging
				m.stateMachine.LogPlayStart("eventHandler", "")

				return "HANDLED"
				
            else if event["EventType"] = "EXIT_SIGNAL" then

                m.bsp.diagnostics.PrintDebug(m.id$ + ": exit signal")
            
            else
            
		        return m.MediaItemEventHandler(event, stateData)

			endif
			
		endif
		
    else
        return m.MediaItemEventHandler(event, stateData)
	endif

    stateData.nextState = m.superState
    return "SUPER"

End Function


Function STRFScanHandler(event As Object, stateData As Object) As Object

    MEDIA_END = 8

    stateData.nextState = invalid
    
    if type(event) = "roAssociativeArray" then      ' internal message event

        if IsString(event["EventType"]) then
        
            if event["EventType"] = "ENTRY_SIGNAL" then
            
                m.bsp.diagnostics.PrintDebug(m.id$ + ": entry signal")

				m.usbInputBuffer$ = ""

				m.bsp.ExecuteMediaStateCommands(m.stateMachine, m)

				m.stateMachine.StopSignChannelInZone()
    
				m.stateMachine.videoPlayer.StopClear()
				m.stateMachine.ClearImagePlane()

				m.channelManager = CreateObject("roChannelManager")
				' m.channelManager.EnableScanDebug("scanDebugOutput.txt") 
				m.channelManager.SetPort(m.bsp.msgPort)

				eventData$ = m.scanSpec["ChannelMap"]

				modulationType = m.scanSpec["ModulationType"]
				if type(modulationType) = "roString" and modulationType <> "" then
					eventData$ = eventData$ + " " + modulationType
				endif

				firstRFChannel = m.scanSpec["FirstRfChannel"]
				if type(firstRFChannel) = "roString" and firstRFChannel <> "" then
					eventData$ = eventData$ + " " + firstRFChannel
				endif

				lastRFChannel = m.scanSpec["LastRfChannel"]
				if type(lastRFChannel) = "roString" and lastRFChannel <> "" then
					eventData$ = eventData$ + " " + lastRFChannel
				endif

                m.bsp.diagnostics.PrintDebug("begin scan: " + eventData$)
			    m.bsp.logging.WriteDiagnosticLogEntry(m.bsp.diagnosticCodes.EVENT_SCAN_START, eventData$)

				m.channelManager.ClearChannelData()
				m.channelManager.AsyncScan(m.scanSpec)

				m.scanInProgress = true

				m.LaunchTimer()    

		        m.bsp.SetTouchRegions(m)

				' state logging
				m.bsp.logging.WriteStateLogEntry(m.stateMachine, m.id$, "tunerScan")

				' playback logging
				m.stateMachine.LogPlayStart("tunerScan", "")

				return "HANDLED"
				
            else if event["EventType"] = "EXIT_SIGNAL" then

				if m.scanInProgress then
					m.bsp.diagnostics.PrintDebug("Cancel tuner scan")
					m.channelManager.CancelScan()
				endif

                m.bsp.diagnostics.PrintDebug(m.id$ + ": exit signal")
            
            else
            
		        return m.MediaItemEventHandler(event, stateData)

			endif
			
		endif
		
    else if type(event) = "roChannelManagerEvent" then

		if event = 0 then

            m.bsp.diagnostics.PrintDebug("Scan complete")
		    m.bsp.logging.WriteDiagnosticLogEntry(m.bsp.diagnosticCodes.EVENT_SCAN_COMPLETE, "")

			m.scanInProgress = false

			' save the current channel
			savedCurrentChannel = invalid
			if m.bsp.scannedChannels.Count() > m.stateMachine.currentChannelIndex%
				savedCurrentChannel = m.bsp.scannedChannels[m.stateMachine.currentChannelIndex%]
			endif

			m.ProcessScannedChannels(m.channelManager)
		
			' reset the current channel
			m.stateMachine.currentChannelIndex% = 0
			if type(savedCurrentChannel) = "roAssociativeArray" then
				for index% = 0 to m.bsp.scannedChannels.Count() - 1
					scannedChannel = m.bsp.scannedChannels[index%]
					if scannedChannel.VirtualChannel = savedCurrentChannel.VirtualChannel then
						m.stateMachine.currentChannelIndex% = index%
						exit for
					endif
				next
			endif

            if type(m.videoEndEvent) = "roAssociativeArray" then
				return m.ExecuteTransition(m.videoEndEvent, stateData, "")
			endif

		else if event = 1 then

			m.bsp.diagnostics.PrintDebug("channel manager progress event - percentage complete =" + stri(event.GetData()))
		
		else if event = 2 then

			channelDescriptor = event.GetChannelDescriptor()
			m.bsp.diagnostics.PrintDebug("Found channel " + channelDescriptor.VirtualChannel)
		    m.bsp.logging.WriteDiagnosticLogEntry(m.bsp.diagnosticCodes.EVENT_CHANNEL_FOUND, channelDescriptor.VirtualChannel)

		endif

	else
        return m.MediaItemEventHandler(event, stateData)
	endif

    stateData.nextState = m.superState
    return "SUPER"

End Function


Sub ProcessScannedChannels(channelManager As Object)

	' Get channel descriptors for all the channels that were found
	channelCount% = channelManager.GetChannelCount()
	channelDescriptors = CreateObject("roArray", channelCount%, false)

	if channelCount% > 0 then
		channelInfo  = CreateObject("roAssociativeArray")
		for channelIndex% = 0 to channelCount% - 1
			channelInfo["ChannelIndex"] = channelIndex%
			channelDescriptor = channelManager.CreateChannelDescriptor(channelInfo)
			channelDescriptors.push(channelDescriptor)
		next
	endif

' Generate XML data for the results of the scan
	docName$ = "BrightSignRFChannels"

	root = CreateObject("roXMLElement")
	root.SetName(docName$)
	root.AddAttribute("version", "1.0")

	rfChannels = root.AddElement("rfChannels")

	' rebuild scanned channels data structure
	m.bsp.scannedChannels.Clear()

	for each channelDescriptor in channelDescriptors

		channelDescriptorElement		= rfChannels.AddElement("rfInputChannel")
		virtualChannelElement			= channelDescriptorElement.AddElement("virtualChannel")
		channelNameElement				= channelDescriptorElement.AddElement("channelName")

		virtualChannelElement.SetBody(channelDescriptor.VirtualChannel)
		channelNameElement.SetBody(channelDescriptor.ChannelName)

		scannedChannelDescriptor = { }
		scannedChannelDescriptor.VirtualChannel = channelDescriptor.VirtualChannel
		scannedChannelDescriptor.ChannelName = channelDescriptor.ChannelName

		m.bsp.scannedChannels.push(scannedChannelDescriptor)

	next

	xml = root.GenXML({ indent: " ", newline: chr(10), header: true })

' Retrieve the XML data for the tuning data produced by system software
	scannedChannelData$ = channelManager.ExportToXml()

' Embed the scanned channel data in the xml as a CDATA element

	' find the insert point in the xml (is there a way to write out a proper element?)
	index% = instr(1, xml, "</" + docName$ + ">")
	if index% > 0 then
		xml = mid(xml, 1, index% - 1)
		xml = xml + " <![CDATA[" + chr(10) + scannedChannelData$ + " ]]>" + chr(10) + "</" + docName$ + ">"
	endif

	ok = WriteAsciiFile("ScannedChannels.xml", xml)

	m.bsp.UpdateRFChannelCountUserVariables(true)

	systemVariableChanged = CreateObject("roAssociativeArray")
	systemVariableChanged["EventType"] = "SYSTEM_VARIABLE_UPDATED"
	m.bsp.msgPort.PostMessage(systemVariableChanged)			

End Sub


Function STRFInputPlayingHandler(event As Object, stateData As Object) As Object

    MEDIA_END = 8

    stateData.nextState = invalid
    
    if type(event) = "roAssociativeArray" then      ' internal message event

        if IsString(event["EventType"]) then

            if event["EventType"] = "ENTRY_SIGNAL" then
            
                m.bsp.diagnostics.PrintDebug(m.id$ + ": entry signal")

				m.ConfigureIntraStateEventHandlerButton(m.channelUpEvent)
				m.ConfigureIntraStateEventHandlerButton(m.channelDownEvent)

				m.usbInputBuffer$ = ""

				m.bsp.ExecuteMediaStateCommands(m.stateMachine, m)

				m.stateMachine.StopSignChannelInZone()
    
				m.stateMachine.videoPlayer.Stop()
				m.stateMachine.ClearImagePlane()

				m.stateMachine.videoPlayer.EnableSafeRegionTrimming(m.overscan)

				if m.stateMachine.firstTuneToChannel or m.reentryAction$ = "Retune" then
					tuneToOriginal = true
				else
					tuneToOriginal = false
				endif

				m.stateMachine.firstTuneToChannel = false

				channelDescriptor = invalid

				if tuneToOriginal then

					if m.firstScannedChannel then

						if m.bsp.scannedChannels.Count() > 0 then
							channelDescriptor = m.bsp.scannedChannels[0]
						else
							m.bsp.SendTuneFailureMessage("No scanned channels")
						endif

					else if type(m.channelDescriptor) = "roAssociativeArray" then

						channelDescriptor = m.channelDescriptor
					
					else if type(m.userVariable) = "roAssociativeArray" then
					
						channelSpec$ = m.userVariable.GetCurrentValue()

						' first look for match with virtual channels; then try channel names if no match found
						for each scannedChannel in m.bsp.scannedChannels
							if scannedChannel.VirtualChannel = channelSpec$ then
								channelDescriptor = scannedChannel
								exit for
							endif
						next

						if channelDescriptor = invalid then
							for each scannedChannel in m.bsp.scannedChannels
								if scannedChannel.ChannelName = channelSpec$ then
									channelDescriptor = scannedChannel
									exit for
								endif
							next
						endif

						if channelDescriptor = invalid then

							m.bsp.SendTuneFailureMessage("No channel found for user variable")

						endif

					else

						m.bsp.SendTuneFailureMessage("No valid channel descriptor")

					endif

					' set the current channel
					if not channelDescriptor = invalid then
						for index% = 0 to m.bsp.scannedChannels.Count() - 1
							scannedChannel = m.bsp.scannedChannels[index%]
							if scannedChannel.VirtualChannel = channelDescriptor.VirtualChannel then
								m.stateMachine.currentChannelIndex% = index%
								exit for
							endif
						next
					endif

				else

					if m.bsp.scannedChannels.Count() > m.stateMachine.currentChannelIndex% then
						channelDescriptor = m.bsp.scannedChannels[m.stateMachine.currentChannelIndex%]
					else
						m.bsp.SendTuneFailureMessage("No scanned channel matches selected channel.")
					endif
								
				endif

				if channelDescriptor = invalid then
					channelToLog$ = "error"
				else
					channelToLog$ = channelDescriptor.VirtualChannel
				endif

				m.bsp.logging.WriteStateLogEntry(m.stateMachine, m.id$, "RFIn " + channelToLog$)

				if type(channelDescriptor) = "roAssociativeArray" then
					m.bsp.TuneToChannel(m.stateMachine.videoPlayer, channelDescriptor)
				endif

				m.LaunchTimer()    

		        m.bsp.SetTouchRegions(m)

				' playback logging
				m.stateMachine.LogPlayStart("RFIn", channelToLog$)

				return "HANDLED"
				
			else if event["EventType"] = "TuneFailureEvent" then

				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "mediaEnd", "", "1")    
				if type(m.videoEndEvent) = "roAssociativeArray" then
					return m.ExecuteTransition(m.videoEndEvent, stateData, "")
				endif

            else if event["EventType"] = "EXIT_SIGNAL" then

                m.bsp.diagnostics.PrintDebug(m.id$ + ": exit signal")
            
			endif
			
		endif
		
	else if type(event) = "roVideoEvent" and event.GetSourceIdentity() = m.stateMachine.videoPlayer.GetIdentity() then            
		if event.GetInt() = MEDIA_END then
			m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "mediaEnd", "", "1")
			if type(m.videoEndEvent) = "roAssociativeArray" then
				return m.ExecuteTransition(m.videoEndEvent, stateData, "")
			endif
		endif
	
	endif

	if type(m.channelUpEvent) = "roAssociativeArray" and m.HandleIntraStateEvent(event, m.channelUpEvent) then
		
		if m.bsp.scannedChannels.Count() = 0 then
			m.bsp.SendTuneFailureMessage("No scanned channels.")
		else
			' perform channel up
			m.bsp.ChangeRFChannel(m.stateMachine, 1)
			channelDescriptor = m.bsp.scannedChannels[m.stateMachine.currentChannelIndex%]
			m.bsp.logging.WriteStateLogEntry(m.stateMachine, m.id$, "RFIn " + channelDescriptor.VirtualChannel)
			m.bsp.TuneToChannel(m.stateMachine.videoPlayer, channelDescriptor)
		endif
		return "HANDLED"
	
	endif

	if type(m.channelDownEvent) = "roAssociativeArray" and m.HandleIntraStateEvent(event, m.channelDownEvent) then

		if m.bsp.scannedChannels.Count() = 0 then
			m.bsp.SendTuneFailureMessage("No scanned channels.")
		else
			' perform channel down
			m.bsp.ChangeRFChannel(m.stateMachine, -1)
			channelDescriptor = m.bsp.scannedChannels[m.stateMachine.currentChannelIndex%]
			m.bsp.logging.WriteStateLogEntry(m.stateMachine, m.id$, "RFIn " + channelDescriptor.VirtualChannel)
			m.bsp.TuneToChannel(m.stateMachine.videoPlayer, channelDescriptor)
			return "HANDLED"
		endif

    endif

    return m.MediaItemEventHandler(event, stateData)

End Function


Sub SendTuneFailureMessage(debugMsg As String)

	m.diagnostics.PrintDebug(debugMsg)
	tuneFailure = CreateObject("roAssociativeArray")
	tuneFailure["EventType"] = "TuneFailureEvent"
	m.msgPort.PostMessage(tuneFailure)

End Sub


Function TuneToChannel(videoPlayer As Object, channelDescriptor As Object)

	m.diagnostics.PrintDebug("Tune to the following channel descriptor:")
    m.diagnostics.PrintDebug("VirtualChannel " + channelDescriptor.VirtualChannel)
'    m.diagnostics.PrintDebug("ChannelName " + channelDescriptor.ChannelName)
'    m.diagnostics.PrintDebug("RFChannel " + stri(channelDescriptor.RFChannel))

	ok = videoPlayer.PlayFile(channelDescriptor)

	if not ok then
		m.SendTuneFailureMessage("Error tuning in TuneToChannel")
	    m.logging.WriteDiagnosticLogEntry(m.diagnosticCodes.EVENT_TUNE_FAILURE, channelDescriptor.VirtualChannel)
	endif

End Function


Function STLiveVideoPlayingEventHandler(event As Object, stateData As Object) As Object

    stateData.nextState = invalid
    
    if type(event) = "roAssociativeArray" then      ' internal message event

        if IsString(event["EventType"]) then
        
            if event["EventType"] = "ENTRY_SIGNAL" then
            
                m.bsp.diagnostics.PrintDebug(m.id$ + ": entry signal")

				m.usbInputBuffer$ = ""

				m.bsp.ExecuteMediaStateCommands(m.stateMachine, m)

				m.stateMachine.StopSignChannelInZone()
    
				m.stateMachine.videoPlayer.Stop()
				m.stateMachine.ClearImagePlane()

				if m.bsp.sysInfo.deviceFamily$ = "cheetah" then
					' HDMI In
					m.stateMachine.videoPlayer.EnableSafeRegionTrimming(m.overscan)
				else
					m.stateMachine.videoPlayer.EnableSafeRegionTrimming(true)
				endif

				m.stateMachine.videoPlayer.PlayEx(m.stateMachine.videoInput)

				m.LaunchTimer()    

		        m.bsp.SetTouchRegions(m)

				' state logging
				m.bsp.logging.WriteStateLogEntry(m.stateMachine, m.id$, "liveVideo")

				' playback logging
				m.stateMachine.LogPlayStart("liveVideo", "")

				return "HANDLED"
				
            else if event["EventType"] = "EXIT_SIGNAL" then

                m.bsp.diagnostics.PrintDebug(m.id$ + ": exit signal")
            
            else
            
		        return m.MediaItemEventHandler(event, stateData)

			endif
			
		endif
		
    else
        return m.MediaItemEventHandler(event, stateData)
	endif

    stateData.nextState = m.superState
    return "SUPER"

End Function


Function STHTML5PlayingEventHandler(event As Object, stateData As Object) As Object

    stateData.nextState = invalid
    
    if type(event) = "roAssociativeArray" then      ' internal message event

        if IsString(event["EventType"]) then
        
            if event["EventType"] = "ENTRY_SIGNAL" then
            
                m.bsp.diagnostics.PrintDebug(m.id$ + ": entry signal")

				m.ConfigureBPButtons()
	
				m.usbInputBuffer$ = ""

				m.bsp.ExecuteMediaStateCommands(m.stateMachine, m)

				m.stateMachine.StopSignChannelInZone()

				m.stateMachine.loadingHtmlWidget = CreateObject("roHtmlWidget", m.stateMachine.rectangle)
				m.stateMachine.loadingHtmlWidget.SetPort(m.bsp.msgPort)

				m.stateMachine.loadingHtmlWidget.EnableSecurity(not m.enableExternalData)
				m.stateMachine.loadingHtmlWidget.EnableMouseEvents(m.enableMouseEvents)

				if m.contentIsLocal then

					syncSpec = CreateObject("roSyncSpec")

					if not syncSpec.ReadFromFile("current-sync.xml") then
						if not syncSpec.ReadFromFile("local-sync.xml") stop
					endif

					assetCollection = syncSpec.GetAssets("download")
					assetPool = CreateObject("roAssetPool", "pool")

					presentationName$ = m.bsp.sign.name$
					stateName$ = m.name$
					prefix$ = m.prefix$

					m.stateMachine.loadingHtmlWidget.MapFilesFromAssetPool(assetPool, assetCollection, prefix$, "/" + prefix$ + "/")
					m.url$ = "file:///" + prefix$ + "/" + m.filePath$
				
				else

					m.url$ = m.url.GetCurrentParameterValue()

				endif

				m.stateMachine.loadingHtmlWidget.SetUrl(m.url$)

				m.LaunchTimer()    

				m.bsp.SetTouchRegions(m)

				' state logging
				m.bsp.logging.WriteStateLogEntry(m.stateMachine, m.id$, "html5")

				' playback logging
				m.stateMachine.LogPlayStart("html5", m.name$)

				return "HANDLED"
				
            else if event["EventType"] = "EXIT_SIGNAL" then

                m.bsp.diagnostics.PrintDebug(m.id$ + ": exit signal")
            
            else
            
		        return m.MediaItemEventHandler(event, stateData)

			endif
			
		endif

	else if type(event) = "roHtmlWidgetEvent" then

		eventData = event.GetData()
		if type(eventData) = "roAssociativeArray" and type(eventData.reason) = "roString" then
            m.bsp.diagnostics.PrintDebug("reason = " + eventData.reason)
			if eventData.reason = "load-error" then
				m.bsp.diagnostics.PrintDebug("message = " + eventData.message)
				m.bsp.logging.WriteDiagnosticLogEntry(m.bsp.diagnosticCodes.EVENT_HTML5_LOAD_ERROR, eventData.message)

				if not m.contentIsLocal then
					m.htmlReloadTimer = CreateObject("roTimer")
					m.htmlReloadTimer.SetPort(m.bsp.msgPort)
					newTimeout = m.bsp.systemTime.GetLocalDateTime()
					newTimeout.AddSeconds(30)
					m.htmlReloadTimer.SetDateTime(newTimeout)
					m.htmlReloadTimer.Start()
				endif
			else if eventData.reason = "load-finished" then
				if type(m.stateMachine.videoPlayer) = "roVideoPlayer" then
					m.stateMachine.videoPlayer.StopClear()
				endif

				m.stateMachine.displayedHtmlWidget = m.stateMachine.loadingHtmlWidget

				m.stateMachine.ShowHtmlWidget()

			endif
		endif

    else if type(event) = "roTimerEvent" then

		if type(m.htmlReloadTimer) = "roTimer" and event.GetSourceIdentity() = m.htmlReloadTimer.GetIdentity() then
			m.bsp.diagnostics.PrintDebug("Reload Html5 widget")
			m.stateMachine.loadingHtmlWidget.SetURL(m.url$)
			return "HANDLED"
		else
	        return m.MediaItemEventHandler(event, stateData)
		endif

	else
        return m.MediaItemEventHandler(event, stateData)
	endif

    stateData.nextState = m.superState
    return "SUPER"

End Function


Function IsPlayingClip() As Boolean

	return m.playingVideoClip or m.playingAudioClip or m.displayingImage
	
End Function


Sub ClearPlayingClip()

	m.playingVideoClip = false
	m.playingAudioClip = false
	m.displayingImage = false

End Sub


Sub ConfigureNavigationButton(navigation As Object)

	if type(navigation) = "roAssociativeArray" then
		if type(navigation.bpEvent) = "roAssociativeArray" then
			bpEvent = navigation.bpEvent
			bpEvent.configuration$ = "press"
			m.bsp.ConfigureBPButton(bpEvent.buttonPanelIndex%, bpEvent.buttonNumber$, bpEvent)
		endif
	endif

End Sub


Function STInteractiveMenuEventHandler(event As Object, stateData As Object) As Object

    MEDIA_END = 8

    stateData.nextState = invalid
    
    if type(event) = "roAssociativeArray" then      ' internal message event

        if IsString(event["EventType"]) then
        
            if event["EventType"] = "ENTRY_SIGNAL" then
            
                m.bsp.diagnostics.PrintDebug(m.id$ + ": entry signal")

				m.playingVideoClip = false
				m.playingAudioClip = false
				m.displayingImage = false

				if type(m.mstimeoutEvent) = "roAssociativeArray" then
					m.inactivityTimer = CreateObject("roTimer")
					m.inactivityTimer.SetPort(m.bsp.msgPort)
					m.RestartInteractiveMenuInactivityTimer()
				endif

				m.imageFileTimeoutTimer = invalid
				
				m.ConfigureBPButtons()

				m.ConfigureNavigationButton(m.upNavigation)
				m.ConfigureNavigationButton(m.downNavigation)
				m.ConfigureNavigationButton(m.leftNavigation)
				m.ConfigureNavigationButton(m.rightNavigation)
				m.ConfigureNavigationButton(m.enterNavigation)
				m.ConfigureNavigationButton(m.backNavigation)
				m.ConfigureNavigationButton(m.nextClipNavigation)
				m.ConfigureNavigationButton(m.previousClipNavigation)

				m.usbInputBuffer$ = ""

				m.stateMachine.StopSignChannelInZone()
    
				m.stateMachine.imagePlayer.SetDefaultTransition(0)

				m.currentInteractiveMenuItem = invalid
				if m.interactiveMenuItems.Count() > 0 then
					m.currentInteractiveMenuNavigationIndex% = 0
					m.currentInteractiveMenuItem = m.interactiveMenuItems[0]
				endif
				
				m.DrawInteractiveMenu()
				
		        m.bsp.SetTouchRegions(m)

				' byte arrays to store stream byte input
				m.serialStreamInputBuffers = CreateObject("roArray", 6, true)
				for i% = 0 to 5
					m.serialStreamInputBuffers[i%] = CreateObject("roByteArray")
				next

				' state logging
				m.bsp.logging.WriteStateLogEntry(m.stateMachine, m.id$, "interactiveMenu")

				' playback logging
				m.stateMachine.LogPlayStart("interactiveMenu", "")

				return "HANDLED"
				
            else if event["EventType"] = "EXIT_SIGNAL" then

                m.bsp.diagnostics.PrintDebug(m.id$ + ": exit signal")
                
				if type(m.inactivityTimer) = "roTimer" then
					m.inactivityTimer.Stop()
				endif

				if type(m.imageFileTimeoutTimer) = "roTimer" then
					m.imageFileTimeoutTimer.Stop()
				endif

                return "HANDLED"
            
			else if event["EventType"] = "BPControlDown" and type(m.currentInteractiveMenuItem) = "roAssociativeArray" then
				bpIndex$ = event["ButtonPanelIndex"]
				bpIndex% = int(val(bpIndex$))
				bpNum$ = event["ButtonNumber"]
				bpNum% = int(val(bpNum$))
				m.bsp.diagnostics.PrintDebug("BP Press" + bpNum$ + " on button panel" + bpIndex$)
				
				if not m.IsPlayingClip() then
				
					if type(m.upNavigation) = "roAssociativeArray" and type(m.upNavigation.bpEvent) = "roAssociativeArray" then
						if m.upNavigation.bpEvent.buttonPanelIndex% = bpIndex% and m.upNavigation.bpEvent.buttonNumber$ = bpNum$ then
							m.NavigateToMenuItem(m.currentInteractiveMenuItem.upNavigationIndex%)
							m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "bpDown", bpIndex$ + " " + bpNum$, "1")
							return "HANDLED"
						endif
					endif

					if type(m.downNavigation) = "roAssociativeArray" and type(m.downNavigation.bpEvent) = "roAssociativeArray" then
						if m.downNavigation.bpEvent.buttonPanelIndex% = bpIndex% and m.downNavigation.bpEvent.buttonNumber$ = bpNum$ then
							m.NavigateToMenuItem(m.currentInteractiveMenuItem.downNavigationIndex%)
							m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "bpDown", bpIndex$ + " " + bpNum$, "1")
							return "HANDLED"
						endif
					endif
					
					if type(m.leftNavigation) = "roAssociativeArray" and type(m.leftNavigation.bpEvent) = "roAssociativeArray" then
						if m.leftNavigation.bpEvent.buttonPanelIndex% = bpIndex% and m.leftNavigation.bpEvent.buttonNumber$ = bpNum$ then
							m.NavigateToMenuItem(m.currentInteractiveMenuItem.leftNavigationIndex%)
							m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "bpDown", bpIndex$ + " " + bpNum$, "1")
							return "HANDLED"
						endif
					endif
					
					if type(m.rightNavigation) = "roAssociativeArray" and type(m.rightNavigation.bpEvent) = "roAssociativeArray" then
						if m.rightNavigation.bpEvent.buttonPanelIndex% = bpIndex% and m.rightNavigation.bpEvent.buttonNumber$ = bpNum$ then
							m.NavigateToMenuItem(m.currentInteractiveMenuItem.rightNavigationIndex%)
							m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "bpDown", bpIndex$ + " " + bpNum$, "1")
							return "HANDLED"
						endif
					endif
					
					if type(m.enterNavigation) = "roAssociativeArray" and type(m.enterNavigation.bpEvent) = "roAssociativeArray" then
						if m.enterNavigation.bpEvent.buttonPanelIndex% = bpIndex% and m.enterNavigation.bpEvent.buttonNumber$ = bpNum$ then
							m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "bpDown", bpIndex$ + " " + bpNum$, "1")
							return m.ExecuteInteractiveMenuEnter(stateData)
						endif
					endif
				
				else
				
					if type(m.backNavigation) = "roAssociativeArray" and type(m.backNavigation.bpEvent) = "roAssociativeArray" then
						if m.backNavigation.bpEvent.buttonPanelIndex% = bpIndex% and m.backNavigation.bpEvent.buttonNumber$ = bpNum$ then
							m.DrawInteractiveMenu()
							m.ClearPlayingClip()
							m.RestartInteractiveMenuInactivityTimer()			
							m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "bpDown", bpIndex$ + " " + bpNum$, "1")
							return "HANDLED"
						endif
					endif
					
					if type(m.nextClipNavigation) = "roAssociativeArray" and type(m.nextClipNavigation.bpEvent) = "roAssociativeArray" then
						if m.nextClipNavigation.bpEvent.buttonPanelIndex% = bpIndex% and m.nextClipNavigation.bpEvent.buttonNumber$ = bpNum$ then
							m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "bpDown", bpIndex$ + " " + bpNum$, "1")
							return m.NextPrevInteractiveMenuLaunchMedia(stateData, 1)
						endif
					endif
					
					if type(m.previousClipNavigation) = "roAssociativeArray" and type(m.previousClipNavigation.bpEvent) = "roAssociativeArray" then
						if m.previousClipNavigation.bpEvent.buttonPanelIndex% = bpIndex% and m.previousClipNavigation.bpEvent.buttonNumber$ = bpNum$ then
							m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "bpDown", bpIndex$ + " " + bpNum$, "1")
							return m.NextPrevInteractiveMenuLaunchMedia(stateData, -1)
						endif
					endif
					
				endif
				
			endif
			
		endif
		
	else if type(event) = "roVideoEvent" and event.GetSourceIdentity() = m.stateMachine.videoPlayer.GetIdentity() then
    
        m.bsp.diagnostics.PrintDebug("Video Event" + stri(event.GetInt()))

		if event.GetInt() = MEDIA_END and m.playingVideoClip then        
        
			m.playingVideoClip = false

			m.DrawInteractiveMenu()
			m.RestartInteractiveMenuInactivityTimer()			

			m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "mediaEnd", "", "1")

		else if event.GetInt() = MEDIA_END and m.playingAudioClip then

			m.playingAudioClip = false

			m.DrawInteractiveMenu()
			m.RestartInteractiveMenuInactivityTimer()			
        
			m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "mediaEnd", "", "1")
        else
			m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "mediaEnd", "", "0")
		endif
        
        return "HANDLED"

	' this should no longer trigger - I think an interactive menu requires a VideoImages zone which doesn't include an audio player
    else if type(event) = "roAudioEvent" then

        m.bsp.diagnostics.PrintDebug("Audio Event" + stri(event.GetInt()))

		if event.GetInt() = MEDIA_END and m.playingAudioClip then
        
			m.playingAudioClip = false

			m.DrawInteractiveMenu()
			m.RestartInteractiveMenuInactivityTimer()			
        
			m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "mediaEnd", "", "1")
        else
			m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "mediaEnd", "", "0")
        endif
        
        return "HANDLED"

	else if type(event) = "roTimerEvent" then
	
		if type(m.inactivityTimer) = "roTimer" and event.GetSourceIdentity() = m.inactivityTimer.GetIdentity() then
			m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "timer", "", "1")
			return m.ExecuteTransition(m.mstimeoutEvent, stateData, "")
		endif

		if type(m.imageFileTimeoutTimer) = "roTimer" and event.GetSourceIdentity() = m.imageFileTimeoutTimer.GetIdentity() then
			if m.displayingImage then
				m.displayingImage = false
				m.DrawInteractiveMenu()
				m.RestartInteractiveMenuInactivityTimer()			
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "timer", "", "1")
			else
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "timer", "", "0")
			endif
			return "HANDLED"
		endif

    else if type(event) = "roStreamByteEvent" and type(m.currentInteractiveMenuItem) = "roAssociativeArray" then

	    m.bsp.diagnostics.PrintDebug("Serial Byte Event " + str(event.GetInt()))
	    
	    serialByte% = event.GetInt()
        port$ = event.GetUserData()

		port% = int(val(port$))
		serialStreamInput = m.serialStreamInputBuffers[port%]
		while serialStreamInput.Count() >= 64
			serialStreamInput.Shift()
		end while
		serialStreamInput.push(serialByte%)

		if not m.IsPlayingClip() then
		
			status$ = m.ConsumeSerialByteInput(stateData, m.upNavigation, m.currentInteractiveMenuItem.upNavigationIndex%, serialStreamInput, port$, "navigate")
			if status$ <> "" return status$
			status$ = m.ConsumeSerialByteInput(stateData, m.downNavigation, m.currentInteractiveMenuItem.downNavigationIndex%, serialStreamInput, port$, "navigate")
			if status$ <> "" return status$
			status$ = m.ConsumeSerialByteInput(stateData, m.leftNavigation, m.currentInteractiveMenuItem.leftNavigationIndex%, serialStreamInput, port$, "navigate")
			if status$ <> "" return status$
			status$ = m.ConsumeSerialByteInput(stateData, m.rightNavigation, m.currentInteractiveMenuItem.rightNavigationIndex%, serialStreamInput, port$, "navigate")
			if status$ <> "" return status$
			status$ = m.ConsumeSerialByteInput(stateData, m.enterNavigation, -1, serialStreamInput, port$, "enter")
			if status$ <> "" return status$
						
		else
		
			status$ = m.ConsumeSerialByteInput(stateData, m.backNavigation, -1, serialStreamInput, port$, "back")
			if status$ <> "" return status$
			status$ = m.ConsumeSerialByteInput(stateData, m.nextClipNavigation, -1, serialStreamInput, port$, "nextClip")
			if status$ <> "" return status$
			status$ = m.ConsumeSerialByteInput(stateData, m.previousClipNavigation, -1, serialStreamInput, port$, "previousClip")
			if status$ <> "" return status$

		endif


    else if type(event) = "roStreamLineEvent" and type(m.currentInteractiveMenuItem) = "roAssociativeArray" then

	    m.bsp.diagnostics.PrintDebug("Serial Line Event " + event.GetString())

        port$ = event.GetUserData()
        serialEvent$ = event.GetString()

		if not m.IsPlayingClip() then

			if type(m.upNavigation) = "roAssociativeArray" and type(m.upNavigation.serialEvent) = "roAssociativeArray" then
				if m.upNavigation.serialEvent.protocol$ <> "Binary" and m.upNavigation.serialEvent.port$ = port$ and m.upNavigation.serialEvent.serial$ = serialEvent$ then
					m.NavigateToMenuItem(m.currentInteractiveMenuItem.upNavigationIndex%)
					m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "serial", port$ + " " + serialEvent$, "1")
					return "HANDLED"
				endif
			endif
	        
			if type(m.downNavigation) = "roAssociativeArray" and type(m.downNavigation.serialEvent) = "roAssociativeArray" then
				if m.downNavigation.serialEvent.protocol$ <> "Binary" and m.downNavigation.serialEvent.port$ = port$ and m.downNavigation.serialEvent.serial$ = serialEvent$ then
					m.NavigateToMenuItem(m.currentInteractiveMenuItem.downNavigationIndex%)
					m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "serial", port$ + " " + serialEvent$, "1")
					return "HANDLED"
				endif
			endif
	        
			if type(m.leftNavigation) = "roAssociativeArray" and type(m.leftNavigation.serialEvent) = "roAssociativeArray" then
				if m.leftNavigation.serialEvent.protocol$ <> "Binary" and m.leftNavigation.serialEvent.port$ = port$ and m.leftNavigation.serialEvent.serial$ = serialEvent$ then
					m.NavigateToMenuItem(m.currentInteractiveMenuItem.leftNavigationIndex%)
					m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "serial", port$ + " " + serialEvent$, "1")
					return "HANDLED"
				endif
			endif
	        
			if type(m.rightNavigation) = "roAssociativeArray" and type(m.rightNavigation.serialEvent) = "roAssociativeArray" then
				if m.rightNavigation.serialEvent.protocol$ <> "Binary" and m.rightNavigation.serialEvent.port$ = port$ and m.rightNavigation.serialEvent.serial$ = serialEvent$ then
					m.NavigateToMenuItem(m.currentInteractiveMenuItem.rightNavigationIndex%)
					m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "serial", port$ + " " + serialEvent$, "1")
					return "HANDLED"
				endif
			endif
	        
			if type(m.enterNavigation) = "roAssociativeArray" and type(m.enterNavigation.serialEvent) = "roAssociativeArray" then
				if m.enterNavigation.serialEvent.protocol$ <> "Binary" and m.enterNavigation.serialEvent.port$ = port$ and m.enterNavigation.serialEvent.serial$ = serialEvent$ then
					m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "serial", port$ + " " + serialEvent$, "1")
					return m.ExecuteInteractiveMenuEnter(stateData)
				endif
			endif
        
        else
        
			if type(m.backNavigation) = "roAssociativeArray" and type(m.backNavigation.serialEvent) = "roAssociativeArray" then
				if m.backNavigation.serialEvent.protocol$ <> "Binary" and m.backNavigation.serialEvent.port$ = port$ and m.backNavigation.serialEvent.serial$ = serialEvent$ then
					m.DrawInteractiveMenu()
					m.ClearPlayingClip()
					m.RestartInteractiveMenuInactivityTimer()			
					m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "serial", port$ + " " + serialEvent$, "1")
					return "HANDLED"
				endif
			endif
			
			if type(m.nextClipNavigation) = "roAssociativeArray" and type(m.nextClipNavigation.serialEvent) = "roAssociativeArray" then
				if m.nextClipNavigation.serialEvent.protocol$ <> "Binary" and m.nextClipNavigation.serialEvent.port$ = port$ and m.nextClipNavigation.serialEvent.serial$ = serialEvent$ then
					m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "serial", port$ + " " + serialEvent$, "1")
					return m.NextPrevInteractiveMenuLaunchMedia(stateData, 1)
				endif
			endif
			
			if type(m.previousClipNavigation) = "roAssociativeArray" and type(m.previousClipNavigation.serialEvent) = "roAssociativeArray" then
				if m.previousClipNavigation.serialEvent.protocol$ <> "Binary" and m.previousClipNavigation.serialEvent.port$ = port$ and m.previousClipNavigation.serialEvent.serial$ = serialEvent$ then
					m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "serial", port$ + " " + serialEvent$, "1")
					return m.NextPrevInteractiveMenuLaunchMedia(stateData, -1)
				endif
			endif
						
		endif			

    else if type(event) = "roControlDown" and stri(event.GetSourceIdentity()) = stri(m.bsp.controlPort.GetIdentity()) and type(m.currentInteractiveMenuItem) = "roAssociativeArray" then
	
		gpioIndex% = event.GetInt()
        gpioNum$ = StripLeadingSpaces(str(event.GetInt()))

		if not m.IsPlayingClip() then

			if type(m.upNavigation) = "roAssociativeArray" and IsInteger(m.upNavigation.gpioUserEvent%) and m.upNavigation.gpioUserEvent% = gpioIndex% then
				m.NavigateToMenuItem(m.currentInteractiveMenuItem.upNavigationIndex%)
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "gpioButton", gpioNum$, "1")
				return "HANDLED"
			endif
			
			if type(m.downNavigation) = "roAssociativeArray" and IsInteger(m.downNavigation.gpioUserEvent%) and m.downNavigation.gpioUserEvent% = gpioIndex% then
				m.NavigateToMenuItem(m.currentInteractiveMenuItem.downNavigationIndex%)
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "gpioButton", gpioNum$, "1")
				return "HANDLED"
			endif
			
			if type(m.leftNavigation) = "roAssociativeArray" and IsInteger(m.leftNavigation.gpioUserEvent%) and m.leftNavigation.gpioUserEvent% = gpioIndex% then
				m.NavigateToMenuItem(m.currentInteractiveMenuItem.leftNavigationIndex%)
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "gpioButton", gpioNum$, "1")
				return "HANDLED"
			endif
			
			if type(m.rightNavigation) = "roAssociativeArray" and IsInteger(m.rightNavigation.gpioUserEvent%) and m.rightNavigation.gpioUserEvent% = gpioIndex% then
				m.NavigateToMenuItem(m.currentInteractiveMenuItem.rightNavigationIndex%)
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "gpioButton", gpioNum$, "1")
				return "HANDLED"
			endif
			
			if type(m.enterNavigation) = "roAssociativeArray" and IsInteger(m.enterNavigation.gpioUserEvent%) and m.enterNavigation.gpioUserEvent% = gpioIndex% then
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "gpioButton", gpioNum$, "1")
				return m.ExecuteInteractiveMenuEnter(stateData)
			endif
			
		else
		
			if type(m.backNavigation) = "roAssociativeArray" and IsInteger(m.backNavigation.gpioUserEvent%) and m.backNavigation.gpioUserEvent% = gpioIndex% then
				m.DrawInteractiveMenu()
				m.ClearPlayingClip()
				m.RestartInteractiveMenuInactivityTimer()			
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "gpioButton", gpioNum$, "1")
				return "HANDLED"
			endif

			if type(m.nextClipNavigation) = "roAssociativeArray" and IsInteger(m.nextClipNavigation.gpioUserEvent%) and m.nextClipNavigation.gpioUserEvent% = gpioIndex% then
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "gpioButton", gpioNum$, "1")
				return m.NextPrevInteractiveMenuLaunchMedia(stateData, 1)
			endif

			if type(m.previousClipNavigation) = "roAssociativeArray" and IsInteger(m.previousClipNavigation.gpioUserEvent%) and m.previousClipNavigation.gpioUserEvent% = gpioIndex% then
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "gpioButton", gpioNum$, "1")
				return m.NextPrevInteractiveMenuLaunchMedia(stateData, -1)
			endif

		endif
	
	else if type(event) = "roIRRemotePress" and type(m.currentInteractiveMenuItem) = "roAssociativeArray" then
	
		remoteEvent% = event.GetInt()
		remoteEvent$ = ConvertToRemoteCommand(remoteEvent%)
		
		if not m.IsPlayingClip() then

			if type(m.upNavigation) = "roAssociativeArray" and IsString(m.upNavigation.remoteEvent$) and m.upNavigation.remoteEvent$ = remoteEvent$ then
				m.NavigateToMenuItem(m.currentInteractiveMenuItem.upNavigationIndex%)
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "remote", remoteEvent$, "1")
				return "HANDLED"
			endif
			
			if type(m.downNavigation) = "roAssociativeArray" and IsString(m.downNavigation.remoteEvent$) and m.downNavigation.remoteEvent$ = remoteEvent$ then
				m.NavigateToMenuItem(m.currentInteractiveMenuItem.downNavigationIndex%)
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "remote", remoteEvent$, "1")
				return "HANDLED"
			endif
			
			if type(m.leftNavigation) = "roAssociativeArray" and IsString(m.leftNavigation.remoteEvent$) and m.leftNavigation.remoteEvent$ = remoteEvent$ then
				m.NavigateToMenuItem(m.currentInteractiveMenuItem.leftNavigationIndex%)
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "remote", remoteEvent$, "1")
				return "HANDLED"
			endif
			
			if type(m.rightNavigation) = "roAssociativeArray" and IsString(m.rightNavigation.remoteEvent$) and m.rightNavigation.remoteEvent$ = remoteEvent$ then
				m.NavigateToMenuItem(m.currentInteractiveMenuItem.rightNavigationIndex%)
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "remote", remoteEvent$, "1")
				return "HANDLED"
			endif

			if type(m.enterNavigation) = "roAssociativeArray" and IsString(m.enterNavigation.remoteEvent$) and m.enterNavigation.remoteEvent$ = remoteEvent$ then
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "remote", remoteEvent$, "1")
				return m.ExecuteInteractiveMenuEnter(stateData)
			endif
				
		else
		
			if type(m.backNavigation) = "roAssociativeArray" and IsString(m.backNavigation.remoteEvent$) and m.backNavigation.remoteEvent$ = remoteEvent$ then
				m.DrawInteractiveMenu()
				m.ClearPlayingClip()
				m.RestartInteractiveMenuInactivityTimer()			
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "remote", remoteEvent$, "1")
				return "HANDLED"
			endif
			
			if type(m.nextClipNavigation) = "roAssociativeArray" and IsString(m.nextClipNavigation.remoteEvent$) and m.nextClipNavigation.remoteEvent$ = remoteEvent$ then
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "remote", remoteEvent$, "1")
				return m.NextPrevInteractiveMenuLaunchMedia(stateData, 1)
			endif

			if type(m.previousClipNavigation) = "roAssociativeArray" and IsString(m.previousClipNavigation.remoteEvent$) and m.previousClipNavigation.remoteEvent$ = remoteEvent$ then
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "remote", remoteEvent$, "1")
				return m.NextPrevInteractiveMenuLaunchMedia(stateData, -1)
			endif
			
		endif

	else if type(event) = "roKeyboardPress" and type(m.currentInteractiveMenuItem) = "roAssociativeArray" then

		keyboardChar$ = chr(event.GetInt())

		' <any> is not supported here - it doesn't make sense.
		
		' if keyboard input is non printable character, convert it to the special code
		keyboardCode$ = m.bsp.GetNonPrintableKeyboardCode(event.GetInt())
		if keyboardCode$ <> "" then
			keyboardChar$ = keyboardCode$
		endif

		if not m.IsPlayingClip() then

			if type(m.upNavigation) = "roAssociativeArray" and IsString(m.upNavigation.keyboardChar$) and m.upNavigation.keyboardChar$ = keyboardChar$ then
				m.NavigateToMenuItem(m.currentInteractiveMenuItem.upNavigationIndex%)
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "keyboard", keyboardChar$, "1")
				return "HANDLED"
			endif
			
			if type(m.downNavigation) = "roAssociativeArray" and IsString(m.downNavigation.keyboardChar$) and m.downNavigation.keyboardChar$ = keyboardChar$ then
				m.NavigateToMenuItem(m.currentInteractiveMenuItem.downNavigationIndex%)
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "keyboard", keyboardChar$, "1")
				return "HANDLED"
			endif
			
			if type(m.leftNavigation) = "roAssociativeArray" and IsString(m.leftNavigation.keyboardChar$) and m.leftNavigation.keyboardChar$ = keyboardChar$ then
				m.NavigateToMenuItem(m.currentInteractiveMenuItem.leftNavigationIndex%)
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "keyboard", keyboardChar$, "1")
				return "HANDLED"
			endif
			
			if type(m.rightNavigation) = "roAssociativeArray" and IsString(m.rightNavigation.keyboardChar$) and m.rightNavigation.keyboardChar$ = keyboardChar$ then
				m.NavigateToMenuItem(m.currentInteractiveMenuItem.rightNavigationIndex%)
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "keyboard", keyboardChar$, "1")
				return "HANDLED"
			endif

			if type(m.enterNavigation) = "roAssociativeArray" and IsString(m.enterNavigation.keyboardChar$) and m.enterNavigation.keyboardChar$ = keyboardChar$ then
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "keyboard", keyboardChar$, "1")
				return m.ExecuteInteractiveMenuEnter(stateData)
			endif
				
		else
		
			if type(m.backNavigation) = "roAssociativeArray" and IsString(m.backNavigation.keyboardChar$) and m.backNavigation.keyboardChar$ = keyboardChar$ then
				m.DrawInteractiveMenu()
				m.ClearPlayingClip()
				m.RestartInteractiveMenuInactivityTimer()			
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "keyboard", keyboardChar$, "1")
				return "HANDLED"
			endif
			
			if type(m.nextClipNavigation) = "roAssociativeArray" and IsString(m.nextClipNavigation.keyboardChar$) and m.nextClipNavigation.keyboardChar$ = keyboardChar$ then
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "keyboard", keyboardChar$, "1")
				return m.NextPrevInteractiveMenuLaunchMedia(stateData, 1)
			endif

			if type(m.previousClipNavigation) = "roAssociativeArray" and IsString(m.previousClipNavigation.keyboardChar$) and m.previousClipNavigation.keyboardChar$ = keyboardChar$ then
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "keyboard", keyboardChar$, "1")
				return m.NextPrevInteractiveMenuLaunchMedia(stateData, -1)
			endif
			
		endif
				
	endif

    return m.MediaItemEventHandler(event, stateData)

End Function


Function ConsumeSerialByteInput(stateData As Object, navigation As Object, navigationIndex% As integer, serialStreamInput As Object, port$ As String, command$ As String) As String
			
	if type(navigation) = "roAssociativeArray" and type(navigation.serialEvent) = "roAssociativeArray" then
		if navigation.serialEvent.protocol$ = "Binary" and navigation.serialEvent.port$ = port$ then
			if ByteArraysMatch(serialStreamInput, navigation.serialEvent.inputSpec) then
				serialStreamInput.Clear()
				m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "serialBytes", navigation.serialEvent.asciiSpec, "1")
				if command$ = "navigate" then
					m.NavigateToMenuItem(navigationIndex%)
				else if command$ = "enter" then
					return m.ExecuteInteractiveMenuEnter(stateData)
				else if command$ = "back" then
					m.DrawInteractiveMenu()
					m.ClearPlayingClip()
					m.RestartInteractiveMenuInactivityTimer()			
				else if command$ = "nextClip" then
					return m.NextPrevInteractiveMenuLaunchMedia(stateData, 1)
				else if command$ = "previousClip" then
					return m.NextPrevInteractiveMenuLaunchMedia(stateData, -1)
				endif
				return "HANDLED"
			endif
		endif
	endif

	return ""
	
End Function


Function ExecuteInteractiveMenuEnter(stateData As Object) As String

	if type(m.inactivityTimer) = "roTimer" then
		m.inactivityTimer.Stop()
	endif

	' execute commands
	if type(m.currentInteractiveMenuItem.enterCmds) = "roArray" then

		for each cmd in m.currentInteractiveMenuItem.enterCmds

			if cmd.name$ = "switchPresentation" then
				presentationName$ = cmd.parameters["presentationName"].GetCurrentParameterValue()
				switchToNewPresentation = m.bsp.ExecuteSwitchPresentationCommand(presentationName$)
				if switchToNewPresentation then
					return "HANDLED"
				endif
			endif

			m.bsp.ExecuteCmd(m.stateMachine, cmd.name$, cmd.parameters)

		next

	endif
	
	launchedPlayback = false
	if m.currentInteractiveMenuItem.targetType$ = "mediaFile" then
		if IsString(m.currentInteractiveMenuItem.targetVideoFile$) and m.currentInteractiveMenuItem.targetVideoFile$ <> "" then
			m.LaunchInteractiveMenuVideoClip(m.currentInteractiveMenuItem, m.currentInteractiveMenuItem.targetVideoFileUserVariable)
			launchedPlayback = true
		else if IsString(m.currentInteractiveMenuItem.targetAudioFile$) and m.currentInteractiveMenuItem.targetAudioFile$ <> "" then
			m.LaunchInteractiveMenuAudioClip(m.currentInteractiveMenuItem, m.currentInteractiveMenuItem.targetAudioFileUserVariable)
			launchedPlayback = true
		else if IsString(m.currentInteractiveMenuItem.targetImageFile$) and m.currentInteractiveMenuItem.targetImageFile$ <> "" then
			file$ = m.currentInteractiveMenuItem.targetImageFile$
			m.DisplayInteractiveMenuImage(file$, m.currentInteractiveMenuItem.targetImageFileUserVariable, m.currentInteractiveMenuItem.targetImageFileTimeout%, m.currentInteractiveMenuItem.targetImageFileUseImageBuffer)
			launchedPlayback = true
		endif
	else if m.currentInteractiveMenuItem.targetType$ = "mediaState" then
	    stateData.nextState = m.stateMachine.stateTable[m.currentInteractiveMenuItem.targetMediaState$]
		m.UpdatePreviousCurrentStateNames()
	    return "TRANSITION"
	else if m.currentInteractiveMenuItem.targetType$ = "previousState" then
	    stateData.nextState = m.stateMachine.stateTable[m.stateMachine.previousStateName$]
		m.UpdatePreviousCurrentStateNames()
	    return "TRANSITION"
	else ' currentState
	endif
	
	if not launchedPlayback and type(m.inactivityTimer) = "roTimer" then
		m.RestartInteractiveMenuInactivityTimer()
	endif
		
	return "HANDLED"
				
End Function


Function NextPrevInteractiveMenuLaunchMedia(stateData As Object, incrementValue% As Integer) As String
	
	while true
	
		m.currentInteractiveMenuNavigationIndex% = m.currentInteractiveMenuNavigationIndex% + incrementValue%
		if incrementValue% > 0 then
			if m.currentInteractiveMenuNavigationIndex% >= m.interactiveMenuItems.Count() then
				m.currentInteractiveMenuNavigationIndex% = 0
			endif
		else
			if m.currentInteractiveMenuNavigationIndex% < 0 then
				m.currentInteractiveMenuNavigationIndex% = m.interactiveMenuItems.Count() - 1
			endif
		endif
		
		m.currentInteractiveMenuItem = m.interactiveMenuItems[m.currentInteractiveMenuNavigationIndex%]
		
		' execute commands
		if type(m.currentInteractiveMenuItem.enterCmds) = "roArray" then
			for each cmd in m.currentInteractiveMenuItem.enterCmds
				m.bsp.ExecuteCmd(m.stateMachine, cmd.name$, cmd.parameters)
			next
		endif
		
		if m.currentInteractiveMenuItem.targetType$ = "mediaFile" then
			if IsString(m.currentInteractiveMenuItem.targetVideoFile$) and m.currentInteractiveMenuItem.targetVideoFile$ <> "" then
				m.LaunchInteractiveMenuVideoClip(m.currentInteractiveMenuItem, m.currentInteractiveMenuItem.targetVideoFileUserVariable)
				return "HANDLED"
			else if IsString(m.currentInteractiveMenuItem.targetAudioFile$) and m.currentInteractiveMenuItem.targetAudioFile$ <> "" then
				m.LaunchInteractiveMenuAudioClip(m.currentInteractiveMenuItem, m.currentInteractiveMenuItem.targetAudioFileUserVariable)
				return "HANDLED"
			else if IsString(m.currentInteractiveMenuItem.targetImageFile$) and m.currentInteractiveMenuItem.targetImageFile$ <> "" then
				m.DisplayInteractiveMenuImage(m.currentInteractiveMenuItem.targetImageFile$, m.currentInteractiveMenuItem.targetImageFileUserVariable, m.currentInteractiveMenuItem.targetImageFileTimeout%, m.currentInteractiveMenuItem.targetImageFileUseImageBuffer)
				return "HANDLED"
			endif
		else if m.currentInteractiveMenuItem.targetType$ = "mediaState" then
		    stateData.nextState = m.stateMachine.stateTable[m.currentInteractiveMenuItem.targetMediaState$]
			m.UpdatePreviousCurrentStateNames()
		    return "TRANSITION"
		else if m.currentInteractiveMenuItem.targetType$ = "previousState" then
		    stateData.nextState = m.stateMachine.stateTable[m.stateMachine.previousStateName$]
			m.UpdatePreviousCurrentStateNames()
			return "TRANSITION"
		else ' currentState
		endif
		
	end while

End Function


Sub LaunchInteractiveMenuVideoClip(interactiveMenuItem As Object, userVariable As Object)
	m.stateMachine.videoPlayer.SetLoopMode(0)
	m.stateMachine.videoPlayer.EnableSafeRegionTrimming(false)
	m.stateMachine.videoPlayer.StopClear()
'	m.stateMachine.audioPlayer.Stop()
	file$ = interactiveMenuItem.targetVideoFile$
	filePath$ = GetPoolFilePath(m.bsp.syncPoolFiles, file$)

	aa = { }
	aa.AddReplace("Filename", filePath$)
		
	if type(interactiveMenuItem.probeData) = "roString" then
		m.stateMachine.bsp.diagnostics.PrintDebug("LaunchInteractiveMenuVideoClip: probeData = " + interactiveMenuItem.probeData)
		aa.AddReplace("ProbeString", interactiveMenuItem.probeData)
	endif

	ok = m.stateMachine.videoPlayer.PlayFile(aa)
	if ok = 0 then stop

	m.stateMachine.ClearImagePlane()
	
	if type(userVariable) = "roAssociativeArray" then
		userVariable.Increment()
	endif

	m.playingVideoClip = true
	m.playingAudioClip = false
	m.displayingImage = false
End Sub


Sub LaunchInteractiveMenuAudioClip(interactiveMenuItem As Object, userVariable As Object)

	if type(m.stateMachine.audioPlayer) = "roAudioPlayer" then
		player = m.stateMachine.audioPlayer
		m.stateMachine.audioPlayer.SetLoopMode(0)
		m.stateMachine.audioPlayer.Stop()
	else
		player = m.stateMachine.videoPlayer
		m.stateMachine.videoPlayer.StopClear()
	endif

	file$ = interactiveMenuItem.targetAudioFile$
	filePath$ = GetPoolFilePath(m.bsp.syncPoolFiles, file$)

	aa = { }
	aa.AddReplace("Filename", filePath$)
		
	if type(interactiveMenuItem.probeData) = "roString" then
		m.stateMachine.bsp.diagnostics.PrintDebug("LaunchInteractiveMenuAudioClip: probeData = " + interactiveMenuItem.probeData)
		aa.AddReplace("ProbeString", interactiveMenuItem.probeData)
	endif

	ok = player.PlayFile(aa)
	if ok = 0 then stop
		
	m.stateMachine.ClearImagePlane()
	
	if type(userVariable) = "roAssociativeArray" then
		userVariable.Increment()
	endif

	m.playingAudioClip = true
	m.playingVideoClip = false
	m.displayingImage = false
End Sub


Sub DisplayInteractiveMenuImage(file$ As String, userVariable As Object, timeout% As Integer, useImageBuffer As Boolean)
'	m.stateMachine.audioPlayer.Stop()
	m.stateMachine.videoPlayer.StopClear()
	filePath$ = GetPoolFilePath(m.bsp.syncPoolFiles, file$)

	if useImageBuffer then
		m.bsp.diagnostics.PrintDebug("Use imageBuffer for " + file$ + " in DisplayInteractiveMenuImage.")
		imageBuffer = m.bsp.imageBuffers.Lookup(filePath$)
		m.stateMachine.imagePlayer.DisplayBuffer(imageBuffer, 0, 0)
	else
		ok = m.stateMachine.imagePlayer.PreloadFile(filePath$)
		ok = m.stateMachine.imagePlayer.DisplayPreload()
	endif

	m.stateMachine.ShowImageWidget()
	
	m.playingVideoClip = false
	m.playingAudioClip = false
	m.displayingImage = true

	if type(m.imageFileTimeoutTimer) = "roTimer" then
		m.imageFileTimeoutTimer.Stop()
	else
		m.imageFileTimeoutTimer = CreateObject("roTimer")
		m.imageFileTimeoutTimer.SetPort(m.bsp.msgPort)
	endif
	
	newTimeout = m.bsp.systemTime.GetLocalDateTime()
    newTimeout.AddSeconds(timeout%)
	m.imageFileTimeoutTimer.SetDateTime(newTimeout)
	m.imageFileTimeoutTimer.Start()
	
	if type(userVariable) = "roAssociativeArray" then
		userVariable.Increment()
	endif
		
End Sub


Sub DrawInteractiveMenu()

	' execute entry commands any time the interactive menu is displayed
	m.bsp.ExecuteMediaStateCommands(m.stateMachine, m)

	' display background image if it exists 
	if IsString(m.backgroundImage$) then
		file$ = m.backgroundImage$
		if file$ <> "" then
			filePath$ = GetPoolFilePath(m.bsp.syncPoolFiles, file$)
			m.stateMachine.videoPlayer.StopClear()
		    if m.backgroundImageUseImageBuffer and type(m.bsp.imageBuffers) = "roAssociativeArray" and m.bsp.imageBuffers.DoesExist(filePath$) then
				m.bsp.diagnostics.PrintDebug("Use imageBuffer for " + file$ + " in DrawInteractiveMenu.")
				imageBuffer = m.bsp.imageBuffers.Lookup(filePath$)
				m.stateMachine.imagePlayer.DisplayBuffer(imageBuffer, 0, 0)
			else
				m.bsp.diagnostics.PrintDebug("DisplayFile in STInteractiveMenuEventHandler: " + file$)
				ok = m.stateMachine.imagePlayer.PreloadFile(filePath$)
				if ok = 0 then
					m.bsp.diagnostics.PrintDebug("Error preloading file in DrawInteractiveMenu: " + file$ + ", " + filePath$)
				else
					ok = m.stateMachine.imagePlayer.DisplayPreload()
					if ok = 0 then
						m.bsp.diagnostics.PrintDebug("Error in DisplayPreload in DrawInteractiveMenu: " + file$ + ", " + filePath$)
					endif
				endif  
			endif 

			m.stateMachine.ShowImageWidget()

		else
			m.stateMachine.ClearImagePlane()
		endif
	endif
	
	' draw backgrounds
	for each interactiveMenuItem in m.interactiveMenuItems
		m.DisplayNavigationOverlay(interactiveMenuItem.unselectedImage$, interactiveMenuItem, interactiveMenuItem.unselectedImageUseImageBuffer)
	next
	
	' draw foreground for first menu item
	if type(m.currentInteractiveMenuItem) = "roAssociativeArray" then
		m.DisplayNavigationOverlay(m.currentInteractiveMenuItem.selectedImage$, m.currentInteractiveMenuItem, m.currentInteractiveMenuItem.selectedImageUseImageBuffer)
	endif

	if IsString(m.backgroundImage$) and m.backgroundImage$ <> "" and type(m.backgroundImageUserVariable) = "roAssociativeArray" then
		m.backgroundImageUserVariable.Increment()
	endif
				
End Sub


Sub NavigateToMenuItem(navigationIndex% As Integer)

	m.RestartInteractiveMenuInactivityTimer()

	if navigationIndex% >= 0 then
		m.DisplayNavigationOverlay(m.currentInteractiveMenuItem.unselectedImage$, m.currentInteractiveMenuItem, m.currentInteractiveMenuItem.unselectedImageUseImageBuffer)
		m.currentInteractiveMenuNavigationIndex% = navigationIndex%
		m.currentInteractiveMenuItem = m.interactiveMenuItems[navigationIndex%]
		m.DisplayNavigationOverlay(m.currentInteractiveMenuItem.selectedImage$, m.currentInteractiveMenuItem, m.currentInteractiveMenuItem.selectedImageUseImageBuffer)
	endif

End Sub


Sub RestartInteractiveMenuInactivityTimer()

	if type(m.inactivityTimer) = "roTimer" then
		m.inactivityTimer.Stop()
		newTimeout = m.bsp.systemTime.GetLocalDateTime()
        newTimeout.AddMilliseconds(m.mstimeoutValue%)
		m.inactivityTimer.SetDateTime(newTimeout)
		m.inactivityTimer.Start()
	endif

End Sub


Sub DisplayNavigationOverlay(fileName$ As String, interactiveMenuItem As Object, useImageBuffer As Boolean)

	if IsString(fileName$) and fileName$ <> "" then
	
		filePath$ = GetPoolFilePath(m.bsp.syncPoolFiles, fileName$)
		
		if useImageBuffer then
			m.bsp.diagnostics.PrintDebug("Use imageBuffer for " + fileName$ + " in DisplayNavigationOverlay.")
			imageBuffer = m.bsp.imageBuffers.Lookup(filePath$)
			m.stateMachine.imagePlayer.DisplayBuffer(imageBuffer, interactiveMenuItem.x%,interactiveMenuItem.y%)
		else
			m.bsp.diagnostics.PrintDebug("Overlay image in DisplayNavigationOverlay: " + fileName$)
			ok = m.stateMachine.imagePlayer.OverlayImage(filePath$, interactiveMenuItem.x%, interactiveMenuItem.y%)
			if ok = 0 then
				m.bsp.diagnostics.PrintDebug("Error in OverlayImage in DisplayNavigationOverlay: " + fileName$ + ", " + filePath$)
			endif
		endif
		
		m.stateMachine.ShowImageWidget()

	endif
	
End Sub


Sub ScaleBackgroundImageToFit( backgroundImage As Object )

    xScale = m.backgroundImageWidth% / m.stateMachine.width%
    yScale = m.backgroundImageHeight% / m.stateMachine.height%

    if xScale > yScale then
        x% = 0
        y% = (m.stateMachine.height% - (m.backgroundImageHeight% / xScale)) / 2

        width% = m.backgroundImageWidth% / xScale
        height% = m.backgroundImageHeight% / xScale
    else
        x% = (m.stateMachine.width% - (m.backgroundImageWidth% / yScale)) / 2
        y% = 0

        width% = m.backgroundImageWidth% / yScale
        height% = m.backgroundImageHeight% / yScale
	endif

	backgroundImage["targetRect"] = { x: x%,  y: y%,  w: width%, h: height% }

End Sub


Sub SetBackgroundImageSizeLocation( backgroundImage As Object )

	if m.stateMachine.imageMode% = 0			' center image
        if m.backgroundImageWidth% > m.stateMachine.width% or m.backgroundImageHeight% > m.stateMachine.height% then
            m.ScaleBackgroundImageToFit(backgroundImage)
        else
			x% = (m.stateMachine.width% - m.backgroundImageWidth%) / 2
			y% = (m.stateMachine.height% - m.backgroundImageHeight%) / 2
			backgroundImage["targetRect"] = { x: x%,  y: y%,  w: m.backgroundImageWidth%, h: m.backgroundImageHeight% }
		endif
	else if m.stateMachine.imageMode% = 1		' scale to fit
        m.ScaleBackgroundImageToFit(backgroundImage)
	else if m.stateMachine.imageMode% = 2		' scale to fill and crop
        m.ScaleBackgroundImageToFit(backgroundImage)
	else if m.stateMachine.imageMode%			' scale to fill
		backgroundImage["targetRect"] = { x: 0,  y: 0,  w: m.stateMachine.width%, h: m.stateMachine.height% }
	endif

End Sub


Function TemplateUsesAnyUserVariable() As Boolean

	for each templateItem in m.templateItems
		if templateItem.type$ = "userVariableTemplateItem" then
			return true
		endif
	next

End Function


Function TemplateUsesUserVariable(userVariable As Object) As Boolean

	for each templateItem in m.templateItems
		if templateItem.type$ = "userVariableTemplateItem" then
			if type(templateItem.userVariable) = "roAssociativeArray" then
				if templateItem.userVariable.name$ = userVariable.name$ then
					return true
				endif
			endif
		endif
	next

End Function


Function TemplateUsesSystemVariable() As Boolean

	for each templateItem in m.templateItems
		if templateItem.type$ = "systemVariableTextTemplateItem"
			return true
		endif
	next

End Function


Sub BuildBaseTemplateItem(templateItem As Object, content As Object)

	content["targetRect"] = { x: templateItem.x%,  y: templateItem.y%,  w: templateItem.width%, h: templateItem.height%  }

End Sub


Sub BuildTextTemplateItem(templateItem As Object, content As Object)

	BuildBaseTemplateItem(templateItem, content)

	textAttrs = { }
	textAttrs.color = templateItem.foregroundTextColor$
			
	textAttrs.fontSize = templateItem.fontSize%
			
	if templateItem.font$ <> "System" then
		textAttrs.fontFile = GetPoolFilePath(m.bsp.syncPoolFiles, templateItem.font$)
	endif

	textAttrs.vAlign = "Top"
	textAttrs.hAlign = templateItem.alignment$
	textAttrs.rotation = templateItem.rotation$
						
	content.textAttrs = textAttrs

End Sub


Sub RedisplayTemplateItems()

	m.BuildTemplateItems()

	m.stateMachine.canvasWidget.EnableAutoRedraw(0)

	numLayers% = m.stateMachine.templateObjectsByLayer.Count()
	for i% = 0 to numLayers% - 1
		if type(m.stateMachine.templateObjectsByLayer[i%]) = "roArray" then
			m.stateMachine.canvasWidget.SetLayer(m.stateMachine.templateObjectsByLayer[i%], i% + 1)
		else
			m.stateMachine.canvasWidget.ClearLayer(i% + 1)
		endif
	next

	m.stateMachine.canvasWidget.EnableAutoRedraw(1)

End Sub


Sub BuildTemplateItems()

	m.stateMachine.templateObjectsByLayer = CreateObject("roArray", 1, true)

	for each templateItem in m.templateItems

		text = invalid
		image = invalid

		backgroundLayer% = (templateItem.layer% - 1) * 2 + 1
		contentLayer% = backgroundLayer% + 1

		if templateItem.type$ = "constantTextTemplateItem" then

			text = { }
			text["text"] = templateItem.textString$
			m.BuildTextTemplateItem(templateItem, text)
		
		else if templateItem.type$ = "systemVariableTextTemplateItem" then

			text = { }

			if templateItem.systemVariableType$ = "SerialNumber" then
				text["text"] = m.bsp.sysInfo.deviceUniqueID$
			else if templateItem.systemVariableType$ = "IPAddressWired" then
				text["text"] = m.bsp.sysInfo.ipAddressWired$
			else if templateItem.systemVariableType$ = "IPAddressWireless" then
				text["text"] = m.bsp.sysInfo.ipAddressWireless$
			else if templateItem.systemVariableType$ = "FirmwareVersion" then
				text["text"] = m.bsp.sysInfo.deviceFWVersion$
			else if templateItem.systemVariableType$ = "ScriptVersion" then
				text["text"] = m.bsp.sysInfo.autorunVersion$
			else if templateItem.systemVariableType$ = "RFChannelCount" then
				text["text"] = StripLeadingSpaces(stri(m.bsp.scannedChannels.Count()))
			else if templateItem.systemVariableType$ = "EdidMonitorSerialNumber" then
				text["text"] = m.bsp.sysInfo.edidMonitorSerialNumber$
			else if templateItem.systemVariableType$ = "EdidYearOfManufacture" then
				text["text"] = m.bsp.sysInfo.edidYearOfManufacture$
			else if templateItem.systemVariableType$ = "EdidMonitorName" then
				text["text"] = m.bsp.sysInfo.edidMonitorName$
			else if templateItem.systemVariableType$ = "EdidManufacturer" then
				text["text"] = m.bsp.sysInfo.edidManufacturer$
			else if templateItem.systemVariableType$ = "EdidUnspecifiedText" then
				text["text"] = m.bsp.sysInfo.edidUnspecifiedText$
			else if templateItem.systemVariableType$ = "EdidSerialNumber" then
				text["text"] = m.bsp.sysInfo.edidSerialNumber$
			else if templateItem.systemVariableType$ = "EdidManufacturerProductCode" then
				text["text"] = m.bsp.sysInfo.edidManufacturerProductCode$
			else if templateItem.systemVariableType$ = "EdidWeekOfManufacture" then
				text["text"] = m.bsp.sysInfo.edidWeekOfManufacture$
			endif

			m.BuildTextTemplateItem(templateItem, text)

		else if templateItem.type$ = "mediaCounterTemplateItem" or templateItem.type$ = "userVariableTemplateItem" then

			if type(templateItem.userVariable) = "roAssociativeArray" then
				text = { }
				text["text"] = templateItem.userVariable.GetCurrentValue()
				m.BuildTextTemplateItem(templateItem, text)
			endif

		else if templateItem.type$ = "indexedLiveTextDataEntryTemplateItem" or templateItem.type$ = "titledLiveTextDataEntryTemplateItem" then

			liveDataFeed = templateItem.liveDataFeed
			if m.liveDataFeeds.DoesExist(liveDataFeed.name$) then
				if templateItem.type$ = "indexedLiveTextDataEntryTemplateItem" then
					indexStr$ = templateItem.index.GetCurrentParameterValue()
					index% = int(val(indexStr$))
					if index% > 0 then
						index% = index% - 1
					endif
					if type(liveDataFeed.articles) = "roArray" then
						if index% <= (liveDataFeed.articles.count() - 1) then
							textValue$ = liveDataFeed.articles[index%]
							text = { }
							text["text"] = textValue$
							m.BuildTextTemplateItem(templateItem, text)
						endif
					endif
				else
					title$ = templateItem.title.GetCurrentParameterValue()
					if type(liveDataFeed.articlesByTitle) = "roAssociativeArray" then
						if liveDataFeed.articlesByTitle.DoesExist(title$) then
							textValue$ = liveDataFeed.articlesByTitle.Lookup(title$)
							text = { }
							text["text"] = textValue$
							m.BuildTextTemplateItem(templateItem, text)
						endif
					endif
				endif
			endif

		else if templateItem.type$ = "imageTemplateItem" then

			image = { }
			
			image["filename"] = GetPoolFilePath(m.bsp.syncPoolFiles, templateItem.fileName$)
			image["CompositionMode"] = "source_over"

			' TemplateToDo - do the images care about the stretch/crop mode?
			' m.SetBackgroundImageSizeLocation(backgroundImage)
			BuildBaseTemplateItem(templateItem, image)

		else if templateItem.type$ = "mrssTextTemplateItem" then

			if type(templateItem.textString$) <> "Invalid" then
				text = { }
				text["text"] = templateItem.textString$
				m.BuildTextTemplateItem(templateItem, text)
			endif

		else if templateItem.type$ = "mrssImageTemplateItem" then

			if type(templateItem.fileName$) <> "Invalid" then
				image = { }
			
				image["filename"] = templateItem.fileName$
				image["CompositionMode"] = "source-over"

				' TemplateToDo - do the images care about the stretch/crop mode?
				' m.SetBackgroundImageSizeLocation(backgroundImage)
				BuildBaseTemplateItem(templateItem, image)
			endif

		endif

		m.BuildTemplateItem(text, image, templateItem)

	next

' now add any simple rss items
	if type(m.simpleRSSTextTemplateItems) = "roAssociativeArray" then
		for each simpleRSSId in m.simpleRSSTextTemplateItems
			simpleRSS = m.simpleRSSTextTemplateItems.Lookup(simpleRSSId)
			if type(simpleRSS) = "roAssociativeArray" then
				liveDataFeed = simpleRSS.rssLiveDataFeeds[simpleRSS.currentLiveDataFeedIndex%]
				if m.liveDataFeeds.DoesExist(liveDataFeed.name$) then
					if type(liveDataFeed.articles) = "roArray" then
						if simpleRSS.currentIndex% >= liveDataFeed.articles.count() then
							simpleRSS.currentIndex% = 0
						endif
						index% = simpleRSS.currentIndex%

						' remove the next conditional - it's not needed
						if index% <= (liveDataFeed.articles.count() - 1) then
							for each templateItem in simpleRSS.items
								if templateItem.elementName$ = "title" then
									textValue$ = liveDataFeed.articleTitles[index%]
								else
									textValue$ = liveDataFeed.articles[index%]
								endif
							
								text = { }
								text["text"] = textValue$
								m.BuildTextTemplateItem(templateItem, text)

								m.BuildTemplateItem(text, image, templateItem)
							next

							' first time display - start timer to display next item
							if type(simpleRSS.rssItemTimer) <> "roTimer" then
								simpleRSS.rssItemTimer = CreateObject("roTimer")
							    simpleRSS.rssItemTimer.SetPort(m.stateMachine.msgPort)

								systemTime = CreateObject("roSystemTime")
								newTimeout = systemTime.GetLocalDateTime()
								newTimeout.AddSeconds(simpleRSS.displayTime%)
								simpleRSS.rssItemTimer.SetDateTime(newTimeout)
								simpleRSS.rssItemTimer.Start()
							endif
						endif
					endif
				endif
			endif
		next
	endif

End Sub


Sub BuildTemplateItem(text As Object, image As Object, templateItem As Object)

	if type(text) = "roAssociativeArray" or type(image) = "roAssociativeArray" then

		backgroundLayer% = (templateItem.layer% - 1) * 2 + 1
		contentLayer% = backgroundLayer% + 1

		if type(m.stateMachine.templateObjectsByLayer[contentLayer%]) <> "roArray" then
			m.stateMachine.templateObjectsByLayer[contentLayer%] = CreateObject("roArray", 1, true)
		endif

		if type(text) = "roAssociativeArray" then

			m.stateMachine.templateObjectsByLayer[contentLayer%].push(text)

			if templateItem.backgroundColorSpecified then
			
				backgroundColor = { }
				backgroundColor["color"] = templateItem.backgroundTextColor$
				backgroundColor["targetRect"] = { x: templateItem.x%,  y: templateItem.y%,  w: templateItem.width%, h: templateItem.height%  }

				if type(m.stateMachine.templateObjectsByLayer[backgroundLayer%]) <> "roArray" then
					m.stateMachine.templateObjectsByLayer[backgroundLayer%] = CreateObject("roArray", 1, true)
				endif

				m.stateMachine.templateObjectsByLayer[backgroundLayer%].push(backgroundColor)
			
			endif

		else

			m.stateMachine.templateObjectsByLayer[contentLayer%].push(image)

		endif

	endif

End Sub


Sub SetupTemplateMRSS()

	m.feedRetrieved = false
	m.numFeedFetchRetries = 0
	m.fetchFeedTimer = CreateObject("roTimer")
	m.fetchFeedTimer.SetPort(m.bsp.msgPort)

	if type(m.bsp.feedVideoDownloader) <> "roAssociativeArray" then
		m.bsp.feedVideoDownloader = newFeedVideoDownloader(m.bsp)
	endif

	mrssFeedUrl$ = m.mrssLiveDataFeeds[m.mrssLiveDataFeedIndex%].url.GetCurrentParameterValue()	
	m.bsp.feedPlayer = newFeedPlayer(m.stateMachine, m.stateMachine.imagePlayer, invalid, m.bsp.msgPort, m.bsp.feedVideoDownloader, false, mrssFeedUrl$, 0, m.bsp.diagnostics, false, m.mrssLiveDataFeeds[m.mrssLiveDataFeedIndex%].updateinterval%)
	if not m.bsp.feedPlayer.FetchFeed() then
		m.numFeedFetchRetries = m.numFeedFetchRetries + 1
		m.RestartFetchFeedTimer()
	endif

	m.stateMachine.feedPlayer = m.bsp.feedPlayer

	if type(m.mrssTitleTemplateItem) = "roAssociativeArray" then
		m.mrssTitleTemplateItem.textString$ = invalid
	endif

	if type(m.mrssDescriptionTemplateItem) = "roAssociativeArray" then
		m.mrssDescriptionTemplateItem.textString$ = invalid
	endif

	if type(m.mrssImageTemplateItem) = "roAssociativeArray" then
		m.mrssImageTemplateItem.fileName$ = invalid
	endif

End Sub


Function STTemplatePlayingEventHandler(event As Object, stateData As Object) As Object
    
	stateData.nextState = invalid
    
    if type(event) = "roAssociativeArray" then      ' internal message event

        if IsString(event["EventType"]) then
        
            if event["EventType"] = "ENTRY_SIGNAL" then
            
                m.bsp.diagnostics.PrintDebug(m.id$ + ": entry signal")

				if m.mrssActive then
					m.mrssItemTimer = CreateObject("roTimer")
					m.mrssItemTimer.SetPort(m.stateMachine.msgPort)

					m.mrssImageRetryTimer = CreateObject("roTimer")
					m.mrssImageRetryTimer.SetPort(m.stateMachine.msgPort)
				endif

				' reset indices on entry to the state
				if type(m.simpleRSSTextTemplateItems) = "roAssociativeArray" then
					for each simpleRSSId in m.simpleRSSTextTemplateItems
						simpleRSS = m.simpleRSSTextTemplateItems.Lookup(simpleRSSId)
						if type(simpleRSS) = "roAssociativeArray" then
							simpleRSS.currentIndex% = 0
							simpleRSS.currentLiveDataFeedIndex% = 0
							simpleRSS.rssItemTimer = invalid
						endif
					next
				endif

				m.liveDataFeeds = CreateObject("roAssociativeArray")
				for each liveDataFeedName in m.bsp.liveDataFeeds
					liveDataFeed = m.bsp.liveDataFeeds.Lookup(liveDataFeedName)
					m.liveDataFeeds.AddReplace(liveDataFeedName, liveDataFeed)
				next

				m.ConfigureBPButtons()
	
				m.usbInputBuffer$ = ""

				m.bsp.ExecuteMediaStateCommands(m.stateMachine, m)

				m.stateMachine.StopSignChannelInZone()
    
				if type(m.stateMachine.videoPlayer) = "roVideoPlayer" then
					m.stateMachine.videoPlayer.StopClear()
				endif

				if type(m.mrssLiveDataFeeds) = "roArray" and m.mrssLiveDataFeeds.Count() > 0 then
					m.mrssLiveDataFeedIndex% = 0
					m.SetupTemplateMRSS()
				endif

				if type(m.stateMachine.canvasWidget) <> "roCanvasWidget" then
					r = CreateObject("roRectangle", m.stateMachine.x%, m.stateMachine.y%, m.stateMachine.width%, m.stateMachine.height%)
					m.stateMachine.canvasWidget = CreateObject("roCanvasWidget", r)
				endif

				m.stateMachine.canvasWidget.EnableAutoRedraw(0)

				maxLayer% = 1
				if type(m.stateMachine.templateObjectsByLayer) = "roArray" then
					maxLayer% = m.stateMachine.templateObjectsByLayer.Count()
				endif

				for i% = 1 to maxLayer%
					m.stateMachine.canvasWidget.ClearLayer(i%)
				next

				' display background image if it exists 
				file$ = m.backgroundImage$
				if file$ <> "" then
					backgroundImage = {}
					backgroundImage["filename"] = GetPoolFilePath(m.bsp.syncPoolFiles, file$)
					backgroundImage["CompositionMode"] = "source"

					if m.backgroundImageWidth% <= 0 or m.backgroundImageHeight% <= 0 then
						backgroundImage["targetRect"] = { x: 0,  y: 0,  w: m.stateMachine.width%, h: m.stateMachine.height% }
					else
						m.SetBackgroundImageSizeLocation(backgroundImage)
					endif

					m.stateMachine.canvasWidget.SetLayer(backgroundImage, 0)
				
				else
				
					m.stateMachine.canvasWidget.ClearLayer(0)
				
				endif

				' build arrays of template items & background colors
				m.BuildTemplateItems()

				numLayers% = m.stateMachine.templateObjectsByLayer.Count()

				for i% = 0 to numLayers% - 1
					if type(m.stateMachine.templateObjectsByLayer[i%]) = "roArray" then
						m.stateMachine.canvasWidget.SetLayer(m.stateMachine.templateObjectsByLayer[i%], i% + 1)
					endif
				next

				m.stateMachine.canvasWidget.EnableAutoRedraw(1)

				m.stateMachine.ShowCanvasWidget()

				m.LaunchTimer()    

		        m.bsp.SetTouchRegions(m)

				' state logging
				m.bsp.logging.WriteStateLogEntry(m.stateMachine, m.id$, "liveText")

				' playback logging
				m.stateMachine.LogPlayStart("liveText", "")

                return "HANDLED"

            else if event["EventType"] = "EXIT_SIGNAL" then

                m.bsp.diagnostics.PrintDebug(m.id$ + ": exit signal")

				if m.mrssActive and type(m.fetchFeedTimer) = "roTimer" then
					m.fetchFeedTimer.Stop()
				endif

			else if m.mrssActive and (event["EventType"] = "EndCycleEvent" or event["EventType"] = "LoadEvent") and m.feedRetrieved then
			
				m.bsp.feedPlayer.HandleScriptEvent(event)
				return "HANDLED"
        
			else if m.mrssActive and event["EventType"] = "SignChannelEndEvent" then

				return "HANDLED"
								
            else if event["EventType"] = "USER_VARIABLES_UPDATED" then

				if m.TemplateUsesAnyUserVariable() then
					m.RedisplayTemplateItems()
				endif

				return "HANDLED"

            else if event["EventType"] = "SYSTEM_VARIABLE_UPDATED" then

				if m.TemplateUsesSystemVariable() then
					m.RedisplayTemplateItems()
				endif

				return "HANDLED"

            else if event["EventType"] = "USER_VARIABLE_CHANGE" then

				userVariable =  event["UserVariable"]

				if m.TemplateUsesUserVariable(userVariable) then
					m.RedisplayTemplateItems()
				endif

				return "HANDLED"
				
            else if event["EventType"] = "LIVE_DATA_FEED_UPDATE" then

				liveDataFeed = event["EventData"]

				m.liveDataFeeds.AddReplace(liveDataFeed.name$, liveDataFeed)

				m.RedisplayTemplateItems()

				return "HANDLED"

            else
            
		        return m.MediaItemEventHandler(event, stateData)

			endif

		endif

	else if type(event) = "roUrlEvent" then
    
		if m.mrssActive and type(m.bsp.feedPlayer) = "roAssociativeArray" then

			feedLoadEvent = false
			if event.GetSourceIdentity() = m.bsp.feedPlayer.feedTransfer.GetIdentity() then
				feedLoadEvent = true
			endif
		
			rv = m.bsp.feedPlayer.HandleUrlEvent(event)
		
			if feedLoadEvent then
				if not m.bsp.feedplayer.loadInProgress then
					if not m.bsp.feedplayer.LoadFailed then
						' feed successfully retrieved. set timer for getting next feed
						if not m.feedRetrieved then
							m.TemplateFeedRetrieved()
						endif
					else ' load failed
						m.numFeedFetchRetries = m.numFeedFetchRetries + 1
						if m.numFeedFetchRetries > 5 then
							' unable to retrieve feed from network, try to load feed from cache
							if m.bsp.feedplayer.LoadFeedFile() then
								' local load successful
								if not m.feedRetrieved then
									m.TemplateFeedRetrieved()
								endif
							else
								m.RestartFetchFeedTimer()
							endif
						else
							m.RestartFetchFeedTimer()
						endif
					endif
				endif
			endif
		
			return "HANDLED"
		endif
    
    else if type(event) = "roTimerEvent" then
    
		if (type(m.mrssItemTimer) = "roTimer" and event.GetSourceIdentity() = m.mrssItemTimer.GetIdentity()) or (type(m.mrssImageRetryTimer) = "roTimer" and event.GetSourceIdentity() = m.mrssImageRetryTimer.GetIdentity()) then
			if event.GetSourceIdentity() = m.mrssItemTimer.GetIdentity() then			
    			if m.bsp.feedPlayer.reachedEnd then
					if m.mrssLiveDataFeeds.Count() > 1 then
						m.mrssLiveDataFeedIndex% = m.mrssLiveDataFeedIndex% + 1
						if m.mrssLiveDataFeedIndex% >= m.mrssLiveDataFeeds.Count() then
							m.mrssLiveDataFeedIndex% = 0
						endif
						m.SetupTemplateMRSS()
						return "HANDLED"
					else
						m.bsp.feedPlayer.reachedEnd = false
					endif
				endif
			endif
			m.GetMRSSTemplateItem()
			return "HANDLED"
        else if m.mrssActive and type(m.bsp.feedPlayer) = "roAssociativeArray" and event.GetSourceIdentity() = m.bsp.feedPlayer.feedTimer.GetIdentity() then
            ' could modify HandleTimerEvent to return an indication that a transition should occur.
			if m.feedRetrieved then
	            m.bsp.feedPlayer.HandleTimerEvent(event)
			else
				m.bsp.diagnostics.PrintDebug("FeedPlayer timer event ignored - no feed retrieved")
			endif
            return "HANDLED"
        else if m.mrssActive and type(m.fetchFeedTimer) = "roTimer" and event.GetSourceIdentity() = m.fetchFeedTimer.GetIdentity() then
            m.bsp.diagnostics.PrintDebug("Re-Fetch Feed")
			m.fetchFeedTimer.Stop()
			m.bsp.feedPlayer.FetchFeed()
			return "HANDLED"
		endif

		if type(m.simpleRSSTextTemplateItems) = "roAssociativeArray" then
			for each simpleRSSId in m.simpleRSSTextTemplateItems
				simpleRSS = m.simpleRSSTextTemplateItems.Lookup(simpleRSSId)
				if type(simpleRSS) = "roAssociativeArray" then
					if type(simpleRSS.rssItemTimer) = "roTimer" then
						if event.GetSourceIdentity() = simpleRSS.rssItemTimer.GetIdentity() then

							itemExists = false

							liveDataFeed = simpleRSS.rssLiveDataFeeds[simpleRSS.currentLiveDataFeedIndex%]
							if m.liveDataFeeds.DoesExist(liveDataFeed.name$) then
								if type(liveDataFeed.articles) = "roArray" then
									simpleRSS.currentIndex% = simpleRSS.currentIndex% + 1
									if simpleRSS.currentIndex% >= liveDataFeed.articles.count() then
										simpleRSS.currentIndex% = 0
										simpleRSS.currentLiveDataFeedIndex% = simpleRSS.currentLiveDataFeedIndex% + 1
										if simpleRSS.currentLiveDataFeedIndex% >= simpleRSS.rssLiveDataFeeds.Count() then
											simpleRSS.currentLiveDataFeedIndex% = 0
										endif
										liveDataFeed = simpleRSS.rssLiveDataFeeds[simpleRSS.currentLiveDataFeedIndex%]
										if m.liveDataFeeds.DoesExist(liveDataFeed.name$) then
											if type(liveDataFeed.articles) = "roArray" then
												itemExists = true
											endif
										endif
									else
										itemExists = true
									endif
								endif
							endif

							if itemExists then
								m.RedisplayTemplateItems()

								' restart timer
								systemTime = CreateObject("roSystemTime")
								newTimeout = systemTime.GetLocalDateTime()
								newTimeout.AddSeconds(simpleRSS.displayTime%)
								simpleRSS.rssItemTimer.SetDateTime(newTimeout)
								simpleRSS.rssItemTimer.Start()
							endif

							return "HANDLED"

						endif			
					endif
				endif
			next
		endif

	    return m.MediaItemEventHandler(event, stateData)
	
	else

        return m.MediaItemEventHandler(event, stateData)
	
	endif

    stateData.nextState = m.superState
    return "SUPER"

End Function


Sub TemplateFeedRetrieved()

	m.feedRetrieved = true
	m.bsp.feedplayer.addSecsToTimer (m.bsp.feedplayer.feed.ttlSeconds, m.bsp.feedplayer.feedTimer)
	m.bsp.feedplayer.cacheManager.Prune(m.bsp.feedplayer.feed, m.bsp.feedplayer, false)
	m.bsp.feedPlayer.LoadNextItem()
	m.GetMRSSTemplateItem()

End Sub


Function GetNextMRSSTemplateItem() As Object
	
	feedPlayer = m.bsp.feedPlayer

	REM print "into Display next item*******"

	If feedPlayer.feed = Invalid then
		REM print "player has no feed loaded"
	else if type(feedPlayer.feed) <> "roAssociativeArray" then
        feedPlayer.diagnostics.PrintDebug("Feed is not associative array")
'	else if feedPlayer.currentItem <> Invalid and not feedPlayer.CurrentItem.DurationExpired Then
'		REM print "item not expired yet...returning from display next item"
'        feedPlayer.diagnostics.PrintDebug("****************************************************************************")
'        feedPlayer.diagnostics.PrintDebug("***************************  SHould NEVER GET HERE ************************")
	else
		item = feedPlayer.feed.GetNextItem()
		if item = invalid
            feedPlayer.diagnostics.PrintDebug("Item invalid after GetNextItem in DisplayNextItem, feed corruption")
			return invalid
		endif

        feedPlayer.diagnostics.PrintDebug("DISPLAY NEXT - Item Index =" + stri(feedPlayer.feed.currentItemIdx))

		if isImage(item) then	
			fname = feedPlayer.cacheManager.Get(item)
			if fname <> invalid then
				feedPlayer.currentItem = item
				feedPlayer.feed.numTriesToDisplay = 0
'				feedPlayer.CurrentItem.DurationExpired = FALSE
				if feedPlayer.feed.atEnd then 
                    feedPlayer.reachedEnd = TRUE
					feedPlayer.mport.PostMessage (feedPlayer.endCycleEvent)
				end if
				return item
			endif

			REM keep track of the number of times we have tried to display this item
			feedPlayer.feed.numTriesToDisplay = feedPlayer.feed.numTriesToDisplay + 1 

			REM if we have tried less than 5 times to display this image, go back to prev item as to try this one again
			if feedPlayer.feed.numTriesToDisplay < 5 then
				feedPlayer.feed.GoToPrevItem()
                feedPlayer.diagnostics.PrintDebug("DISPLAY NEXT - retry =" + stri(feedPlayer.feed.numTriesToDisplay) + "   Item Index =" + stri(feedPlayer.feed.currentItemIdx))
				REM Retry in 2 seconds
				feedPlayer.AddSecsToTimer(2, m.mrssImageRetryTimer)
			else
                feedPlayer.diagnostics.PrintDebug("******************** TRIED 5 TIMES AND Still Not there  ********")
				feedPlayer.currentItem = item
				feedPlayer.feed.numTriesToDisplay = 0
				if feedPlayer.feed.atEnd then
				    feedPlayer.PostSignChannelEndEvent()
					feedPlayer.mport.PostMessage(feedPlayer.endCycleEvent)
				end if
				REM Item did not load, go to the next item
				feedPlayer.AddSecsToTimer(1, m.mrssImageRetryTimer)
			endif
		endif
	endif

	return invalid

End Function


Sub GetMRSSTemplateItem()

	item = m.GetNextMRSSTemplateItem()

	if type(item) <> "roAssociativeArray" then
		' with the current code, the timer is reset in GetNextMRSSTemplateItem
		return
	endif

	fileName$ = m.bsp.feedPlayer.cacheManager.Get(item)

    systemTime = CreateObject("roSystemTime")
    newTimeout = systemTime.GetLocalDateTime()
    newTimeout.AddSeconds(item.duration)
    m.mrssItemTimer.SetDateTime(newTimeout)
    m.mrssItemTimer.Start()

	if type(m.mrssTitleTemplateItem) = "roAssociativeArray" then
		m.mrssTitleTemplateItem.textString$ = item.title
	endif

	if type(m.mrssDescriptionTemplateItem) = "roAssociativeArray" then
		m.mrssDescriptionTemplateItem.textString$ = item.description
	endif

	if type(m.mrssImageTemplateItem) = "roAssociativeArray" then
		m.mrssImageTemplateItem.fileName$ = fileName$
	endif

	m.RedisplayTemplateItems()

End Sub


Function STPlayingMediaRSSEventHandler(event As Object, stateData As Object) As Object

    stateData.nextState = invalid
    
    if type(event) = "roAssociativeArray" then      ' internal message event

        if IsString(event["EventType"]) then
        
            if event["EventType"] = "ENTRY_SIGNAL" then
            
                m.bsp.diagnostics.PrintDebug(m.id$ + ": entry signal")

				m.ConfigureBPButtons()

				m.feedRetrieved = false
				m.numFeedFetchRetries = 0
				m.fetchFeedTimer = CreateObject("roTimer")
				m.fetchFeedTimer.SetPort(m.bsp.msgPort)
				
				m.usbInputBuffer$ = ""

				m.bsp.ExecuteMediaStateCommands(m.stateMachine, m)

				m.stateMachine.StopSignChannelInZone()
    
				if type(m.stateMachine.videoPlayer) = "roVideoPlayer" then
					videoPlayer = m.stateMachine.videoPlayer
				else
					videoPlayer = invalid
				endif
    
				if type(m.stateMachine.audioPlayer) = "roAudioPlayer" then
					m.stateMachine.audioPlayer.Stop()
				endif
    
		        m.bsp.SetTouchRegions(m)

				' start SignChannel - current implementation does a complete initialization here. may need
				' refactoring required if this is really used as a playlist item (multiple in a presentation)
				if type(m.bsp.feedVideoDownloader) <> "roAssociativeArray" then
					m.bsp.feedVideoDownloader = newFeedVideoDownloader(m.bsp)
				endif
    
				loopMode = true
				if type(m.signChannelEndEvent) = "roAssociativeArray" then loopMode = false
    
				if type(m.bsp.feedPlayer) <> "roAssociativeArray" then
					if type(m.slideTransition%) = "roInt" then
						slideTransition% = m.slideTransition%
					else
						slideTransition% = 0
					endif
				
					m.bsp.feedPlayer = newFeedPlayer(m.stateMachine, m.stateMachine.imagePlayer, videoPlayer, m.bsp.msgPort, m.bsp.feedVideoDownloader, loopMode, m.rssURL$, slideTransition%, m.bsp.diagnostics, m.isDynamicPlaylist, -1)
					if not m.bsp.feedPlayer.FetchFeed() then
						m.numFeedFetchRetries = m.numFeedFetchRetries + 1
						m.RestartFetchFeedTimer()
					endif
				else
					m.bsp.feedPlayer.IsEnabled = true
				endif
				m.stateMachine.feedPlayer = m.bsp.feedPlayer
				
				m.LaunchTimer()    

		        m.bsp.SetTouchRegions(m)

				' state logging
				m.bsp.logging.WriteStateLogEntry(m.stateMachine, m.id$, "mediaRSS")

                return "HANDLED"

            else if event["EventType"] = "EXIT_SIGNAL" then

                m.bsp.diagnostics.PrintDebug(m.id$ + ": exit signal")

				m.fetchFeedTimer.Stop()
				
				m.stateMachine.StopSignChannelInZone()
            
			else if event["EventType"] = "SignChannelEndEvent" then

print "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! SignChannelEndEvent !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
				if type(m.signChannelEndEvent) = "roAssociativeArray" then
					action$ = m.ExecuteTransition(m.signChannelEndEvent, stateData, "")
'					if action$ = "TRANSITION" and type(m.bsp.feedPlayer) = "roAssociativeArray" then
						' clean up cache when exiting media rss display
'						m.bsp.feedPlayer.cacheManager.Prune(m.bsp.feedPlayer.feed, m.bsp.feedplayer, false)
'					endif
					return action$
				endif
				
			else if (event["EventType"] = "EndCycleEvent" or event["EventType"] = "LoadEvent") and m.feedRetrieved then
			
				m.bsp.feedPlayer.HandleScriptEvent(event)
				return "HANDLED"
        
            else
            
		        return m.MediaItemEventHandler(event, stateData)

            endif
            
        endif

    
	else if type(event) = "roUrlEvent" then
    
		feedLoadEvent = false
		if event.GetSourceIdentity() = m.bsp.feedPlayer.feedTransfer.GetIdentity() then
			feedLoadEvent = true
		endif
		
		rv = m.bsp.feedPlayer.HandleUrlEvent(event)
		
		if feedLoadEvent then
			if not m.bsp.feedplayer.loadInProgress then
				if not m.bsp.feedplayer.LoadFailed then
					' feed successfully retrieved. set timer for getting next feed
					m.ShowFeed()
				else ' load failed
					if m.bsp.feedplayer.loadFailureReason = m.bsp.feedplayer.LOAD_EMPTY_RSS and type(m.signChannelEndEvent) = "roAssociativeArray" then
						' exit state
						action$ = m.ExecuteTransition(m.signChannelEndEvent, stateData, "")
						if action$ = "TRANSITION" and type(m.bsp.feedPlayer) = "roAssociativeArray" then
							' clean up cache when exiting media rss display
							if type(m.bsp.feedPlayer.feed) = "roAssociativeArray" then
								m.bsp.feedPlayer.cacheManager.Prune(m.bsp.feedPlayer.feed, m.bsp.feedplayer, false)
							endif
						endif
						return action$
					endif

					m.numFeedFetchRetries = m.numFeedFetchRetries + 1
					if m.numFeedFetchRetries > 5 then
						' unable to retrieve feed from network, try to load feed from cache
						if m.bsp.feedplayer.LoadFeedFile() then
							' local load successful
							m.ShowFeed()
						else if type(m.signChannelEndEvent) = "roAssociativeArray" then
							' exit state
							action$ = m.ExecuteTransition(m.signChannelEndEvent, stateData, "")
							if action$ = "TRANSITION" and type(m.bsp.feedPlayer) = "roAssociativeArray" then
								' clean up cache when exiting media rss display
								if type(m.bsp.feedPlayer.feed) = "roAssociativeArray" then
									m.bsp.feedPlayer.cacheManager.Prune(m.bsp.feedPlayer.feed, m.bsp.feedplayer, false)
								endif
							endif
							return action$
						else
							m.RestartFetchFeedTimer()
						endif
					else
						m.RestartFetchFeedTimer()
					endif
				endif
			endif
		endif
		
		return "HANDLED"
    
    else if type(event) = "roTimerEvent" then
    
        if event.GetSourceIdentity() = m.bsp.feedPlayer.imageTimer.GetIdentity() or event.GetSourceIdentity() = m.bsp.feedPlayer.imageRetryTimer.GetIdentity() or event.GetSourceIdentity() = m.bsp.feedPlayer.feedTimer.GetIdentity() then
            ' could modify HandleTimerEvent to return an indication that a transition should occur.
			if m.feedRetrieved then
	            m.bsp.feedPlayer.HandleTimerEvent(event)
			else
				m.bsp.diagnostics.PrintDebug("FeedPlayer timer event ignored - no feed retrieved")
			endif
            return "HANDLED"
        else if event.GetSourceIdentity() = m.fetchFeedTimer.GetIdentity() then
            m.bsp.diagnostics.PrintDebug("Re-Fetch Feed")
			m.fetchFeedTimer.Stop()
			m.bsp.feedPlayer.FetchFeed()
			return "HANDLED"
		else
		    return m.MediaItemEventHandler(event, stateData)
		endif

	else if type(event) = "roVideoEvent" and type(m.stateMachine.videoPlayer) = "roVideoPlayer" and event.GetSourceIdentity() = m.stateMachine.videoPlayer.GetIdentity() then

	    if type(m.bsp.feedPlayer) = "roAssociativeArray" and m.bsp.feedPlayer.IsEnabled and type(m.bsp.feedPlayer.videoPlayer) = "roVideoPlayer" then
			if m.feedRetrieved then
				m.bsp.feedPlayer.HandleVideoEvent(event)
			else
				m.bsp.diagnostics.PrintDebug("FeedPlayer video event ignored - no feed retrieved")
			endif
			return "HANDLED"
		endif
		
    else
    
        return m.MediaItemEventHandler(event, stateData)
	
	endif

    stateData.nextState = m.superState
    return "SUPER"

End Function


Sub ShowFeed()
	if not m.feedRetrieved then
		m.feedRetrieved = true
		m.bsp.feedplayer.addSecsToTimer (m.bsp.feedplayer.feed.ttlSeconds, m.bsp.feedplayer.feedTimer)
		m.bsp.feedplayer.cacheManager.Prune(m.bsp.feedplayer.feed, m.bsp.feedplayer, false)
		m.bsp.feedPlayer.LoadNextItem()
		m.bsp.feedPlayer.DisplayNextItem()
	endif
End Sub


Sub RestartFetchFeedTimer()
	' wait five seconds, then try again
	m.bsp.diagnostics.PrintDebug("Set timer to re-Fetch Feed")
	newTimeout = m.bsp.systemTime.GetLocalDateTime()
	newTimeout.AddSeconds(5)
	m.fetchFeedTimer.SetDateTime(newTimeout)
	m.fetchFeedTimer.Start()
End Sub


Sub StopSignChannelInZone()

' check for existence of feed player
    if type(m.bsp.feedPlayer) <> "roAssociativeArray" then return

' only stop SignChannel if the zone provided matches the zone that SignChannel is using
    if type(m.feedPlayer) <> "roAssociativeArray" then return
    
    m.feedPlayer = invalid
        
    m.bsp.StopSignChannel()
    
End Sub


Sub StopSignChannel()

' remove circular reference
    if type(m.feedPlayer) = "roAssociativeArray" then
        if type(m.feedPlayer.feed) = "roAssociativeArray" then
            m.feedPlayer.feed.feedPlayer = invalid
        endif
        m.feedPlayer = invalid
'         print "$$$$ destroy feedPlayer object"
    endif

End Sub


Sub LaunchMixerAudio(playbackIndex% As Integer, playImmediate As Boolean)

	m.ConfigureBPButtons()
	
	m.usbInputBuffer$ = ""

    if type(m.stateMachine.videoPlayer) = "roVideoPlayer" then
        m.stateMachine.videoPlayer.StopClear()
    endif
    
    loopMode% = 1
    if type(m.audioEndEvent) = "roAssociativeArray" then loopMode% = 0
    m.stateMachine.audioPlayer.SetLoopMode(loopMode%)

' can't stop since this is code is often just queuing up a track - will this cause any repercussions?
'	m.stateMachine.audioPlayer.Stop()
	if playImmediate then
		m.stateMachine.audioPlayer.Stop()
	endif

	m.bsp.ExecuteMediaStateCommands(m.stateMachine, m)

    file$ = m.audioItem.fileName$
    filePath$ = GetPoolFilePath(m.bsp.syncPoolFiles, file$)

    track = CreateObject("roAssociativeArray")
    track["Filename"] = filePath$
    track["QueueNext"] = 1
'    track["Algorithm"] = "muzak"
'    track["EncryptionKey"] = playlistPath$
	track["UserString"]= playbackIndex%

	fadeLength% = m.stateMachine.fadelength% * 1000
    track["FadeInLength"] = fadeLength%
    track["FadeOutLength"] = fadeLength%

	if playImmediate then
		track["FadeCurrentPlayNext"] = 0
	endif

	ok = m.stateMachine.audioPlayer.PlayFile(track)

    m.bsp.SetTouchRegions(m)

	m.stateMachine.ClearImagePlane()

    m.LaunchTimer()    

	if type(m.audioItem.userVariable) = "roAssociativeArray" then
		m.audioItem.userVariable.Increment()
	endif
    
	' state logging
	m.bsp.logging.WriteStateLogEntry(m.stateMachine, m.id$, "audioMx")

	' playback logging
	m.stateMachine.LogPlayStart("audioMx", file$)

End Sub


Function STAudioPlayingEventHandler(event As Object, stateData As Object) As Object

    MEDIA_END = 8
	
    stateData.nextState = invalid
    
    if type(event) = "roAssociativeArray" then      ' internal message event

        if IsString(event["EventType"]) then
        
            if event["EventType"] = "ENTRY_SIGNAL" then
            
                m.bsp.diagnostics.PrintDebug(m.id$ + ": entry signal")

				if m.stateMachine.type$ = "EnhancedAudio" then
					m.LaunchMixerAudio(-1, true)
				else		
					m.LaunchAudio("audio")
				endif

                return "HANDLED"

            else if event["EventType"] = "AudioPlaybackFailureEvent" then

                if type(m.audioEndEvent) = "roAssociativeArray" then
                    return m.ExecuteTransition(m.audioEndEvent, stateData, "")
                endif

            else if event["EventType"] = "EXIT_SIGNAL" then

                m.bsp.diagnostics.PrintDebug(m.id$ + ": exit signal")
            
            else
            
		        return m.MediaItemEventHandler(event, stateData)

            endif
            
        endif

	else if m.stateMachine.type$ = "EnhancedAudio" and type(event) = "roAudioEventMx" then
        if event.GetInt() = MEDIA_END then
            m.bsp.diagnostics.PrintDebug("Audio Event" + stri(event.GetInt()))
			m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "mediaEnd", "", "1")
            if type(m.audioEndEvent) = "roAssociativeArray" then
				return m.ExecuteTransition(m.audioEndEvent, stateData, "")
            endif
        endif
            
    else if IsAudioEvent(m.stateMachine, event) then
        if event.GetInt() = MEDIA_END then
            m.bsp.diagnostics.PrintDebug("Audio Event" + stri(event.GetInt()))
			m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "mediaEnd", "", "1")
            if type(m.audioEndEvent) = "roAssociativeArray" then
				return m.ExecuteTransition(m.audioEndEvent, stateData, "")
            endif
        endif
    else
        return m.MediaItemEventHandler(event, stateData)
	endif

    stateData.nextState = m.superState
    return "SUPER"

End Function

'endregion

'region Background Image State Machine
' *************************************************
'
' Background Image State Machine
'
' *************************************************
Function newBackgroundImageZoneHSM(bsp As Object, zoneXML As Object) As Object

	zoneHSM = newHSM()
	zoneHSM.ConstructorHandler = BackgroundImageZoneConstructor
	zoneHSM.InitialPseudostateHandler = BackgroundImageZoneGetInitialState
	
	newZoneCommon(bsp, zoneXML, zoneHSM)

    return zoneHSM

End Function


Sub BackgroundImageZoneConstructor()

	m.InitializeZoneCommon(m.bsp.msgPort)

    zoneHSM = m
    
    ' create players
    
    videoPlayer = CreateObject("roVideoPlayer")
    if type(videoPlayer) <> "roVideoPlayer" then print "videoPlayer creation failed" : stop
    videoPlayer.SetRectangle(zoneHSM.rectangle)
    
	' Cheetah only
	if m.bsp.sysInfo.deviceFamily$ = "cheetah" then
		videoPlayer.ToBack()
	endif

    zoneHSM.videoPlayer = videoPlayer
    zoneHSM.isVideoZone = true

	m.activeState = m.playlist.firstState
	m.previousStateName$ = m.playlist.firstStateName$
	
	m.CreateObjects()
            
End Sub


Function BackgroundImageZoneGetInitialState() As Object

	return m.activeState

End Function


Function STDisplayingBackgroundImageEventHandler(event As Object, stateData As Object) As Object

    stateData.nextState = invalid
    
    if type(event) = "roAssociativeArray" then      ' internal message event

        if IsString(event["EventType"]) then
        
            if event["EventType"] = "ENTRY_SIGNAL" then
            
                m.bsp.diagnostics.PrintDebug(m.id$ + ": entry signal")

				m.usbInputBuffer$ = ""

				m.bsp.ExecuteMediaStateCommands(m.stateMachine, m)

				file$ = m.backgroundImageItem.fileName$
				filePath$ = GetPoolFilePath(m.bsp.syncPoolFiles, file$)

				ok = m.stateMachine.videoPlayer.PlayStaticImage(filePath$)

				if ok = 0 then
					m.bsp.diagnostics.PrintDebug("Error displaying file in LaunchBackgroundImage: " + file$ + ", " + filePath$)
				else
					m.bsp.diagnostics.PrintDebug("LaunchBackgroundImage: display file " + file$)
				endif   

				if type(m.backgroundImageItem.userVariable) = "roAssociativeArray" then
					m.backgroundImageItem.userVariable.Increment()
				endif
    
				' state logging
				m.bsp.logging.WriteStateLogEntry(m.stateMachine, m.id$, "backgroundImage")

                return "HANDLED"

            else if event["EventType"] = "PREPARE_FOR_RESTART" then

				m.stateMachine.videoPlayer = invalid
				return "HANDLED"
				
            else if event["EventType"] = "EXIT_SIGNAL" then

                m.bsp.diagnostics.PrintDebug(m.id$ + ": exit signal")
            
            else
            
		        return m.MediaItemEventHandler(event, stateData)

            endif
            
        endif
    else
        return m.MediaItemEventHandler(event, stateData)
    endif
            
    stateData.nextState = m.superState
    return "SUPER"
    
End Function

'endregion

'region Clock State Machine
' *************************************************
'
' Clock State Machine
'
' *************************************************
Function newClockZoneHSM(bsp As Object, zoneXML As Object) As Object

	zoneHSM = newHSM()
	zoneHSM.ConstructorHandler = ClockZoneConstructor
	zoneHSM.InitialPseudostateHandler = ClockZoneGetInitialState
	
	newZoneCommon(bsp, zoneXML, zoneHSM)

    displayTime$ = zoneXML.zoneSpecificParameters.displayTime.GetText()
    if lcase(displayTime$) = "true" then
        zoneHSM.displayTime% = 1
    else
        zoneHSM.displayTime% = 0
    endif
    
    REM code below doesn't work with BS 2.0
    ' rotation$ = zoneXML.zoneSpecificParameters.rotation.GetText()
	zoneHSM.rotation% = 0
    ele = zoneXML.zoneSpecificParameters.GetNamedElements("rotation")
    if ele.Count() = 1 then
		rotation$ = ele[0].GetText()
		if rotation$ = "90" then
			zoneHSM.rotation% = 3
		else if rotation$ = "180" then
			zoneHSM.rotation% = 2
		else if rotation$ = "270" then
			zoneHSM.rotation% = 1
		endif
    endif
    
    widget = zoneXML.zoneSpecificParameters.widget
    foregroundTextColor = widget.foregroundTextColor
    zoneHSM.foregroundTextColor% = GetColor(foregroundTextColor.GetAttributes())
    backgroundTextColor = widget.backgroundTextColor
    zoneHSM.backgroundTextColor% = GetColor(backgroundTextColor.GetAttributes())
    zoneHSM.font$ = widget.font.GetText()

    backgroundBitmap = widget.backgroundBitmap
    if backgroundBitmap.Count() = 1 then
        backgroundBitmapAttrs = backgroundBitmap.GetAttributes()
        zoneHSM.backgroundBitmapFile$ = backgroundBitmapAttrs["file"]
        stretchStr = backgroundBitmapAttrs["stretch"]
        if stretchStr = "true" then
            zoneHSM.stretch% = 1
        else
            zoneHSM.stretch% = 0
        endif
    endif
    
    safeTextRegion = widget.safeTextRegion
    if safeTextRegion.Count() = 1 then
        zoneHSM.safeTextRegionX% = int(val(safeTextRegion.safeTextRegionX.GetText()))
        zoneHSM.safeTextRegionY% = int(val(safeTextRegion.safeTextRegionY.GetText()))
        zoneHSM.safeTextRegionWidth% = int(val(safeTextRegion.safeTextRegionWidth.GetText()))
        zoneHSM.safeTextRegionHeight% = int(val(safeTextRegion.safeTextRegionHeight.GetText()))
    endif
    
    zoneHSM.stClock = zoneHSM.newHState(bsp, "Clock")
    zoneHSM.stClock.HStateEventHandler = STClockEventHandler
	zoneHSM.stClock.superState = zoneHSM.stTop
        
	return zoneHSM
		
End Function


Sub ClockZoneConstructor()

	m.InitializeZoneCommon(m.bsp.msgPort)
	
    zoneHSM = m

	globalAA = GetGlobalAA()
    resourceManager = CreateObject("roResourceManager", globalAA.resourcesFilePath$)
    if type(resourceManager) = "roResourceManager" then
        ok = resourceManager.SetLanguage(zoneHSM.language$)
        if not ok then print "No resources for language ";zoneHSM.language$ : stop
        
	    a=CreateObject("roAssociativeArray")
	    if zoneHSM.displayTime% = 1 then
			a["Time"] = 1
			a["Date"] = 0
		else
			a["Time"] = 0
			a["Date"] = 1
		endif
	    a["Rotation"] = zoneHSM.rotation%
        clockWidget = CreateObject("roClockWidget", zoneHSM.rectangle, resourceManager, a)

		if type(clockWidget) = "roClockWidget" then
        
			zoneHSM.widget = clockWidget
		
			if type(zoneHSM.foregroundTextColor%) = "roInt" then
				zoneHSM.widget.SetForegroundColor(zoneHSM.foregroundTextColor%)
			endif

			if type(zoneHSM.backgroundTextColor%) = "roInt" then
				zoneHSM.widget.SetBackgroundColor(zoneHSM.backgroundTextColor%)
			endif
        
			if zoneHSM.font$ <> "" and zoneHSM.font$ <> "System" then
				fontPath$ = GetPoolFilePath(m.bsp.syncPoolFiles, zoneHSM.font$)
				zoneHSM.widget.SetFont(fontPath$)
			endif
                
			if IsString(zoneHSM.backgroundBitmapFile$) then
				backgroundBitmapFilePath$ = GetPoolFilePath(m.bsp.syncPoolFiles, zoneHSM.backgroundBitmapFile$)
				zoneHSM.widget.SetBackgroundBitmap(backgroundBitmapFilePath$, zoneHSM.stretch%)
			endif
                
			if type(zoneHSM.safeTextRegionX%) = "roInt" then
				r = CreateObject("roRectangle", zoneHSM.safeTextRegionX%, zoneHSM.safeTextRegionY%, zoneHSM.safeTextRegionWidth%, zoneHSM.safeTextRegionHeight%)
				zoneHSM.widget.SetSafeTextRegion(r)
				r = 0
			endif

		endif

    endif
    
End Sub


Function ClockZoneGetInitialState() As Object

	return m.stClock

End Function


Function STClockEventHandler(event As Object, stateData As Object) As Object
    
    stateData.nextState = invalid
    
    if type(event) = "roAssociativeArray" then      ' internal message event

        if IsString(event["EventType"]) then
        
            if event["EventType"] = "ENTRY_SIGNAL" then
            
                m.bsp.diagnostics.PrintDebug(m.id$ + ": entry signal")

				if type(m.stateMachine.widget) = "roClockWidget" then
					m.stateMachine.widget.Show()
				endif

                return "HANDLED"

            else if event["EventType"] = "PREPARE_FOR_RESTART" then

				m.stateMachine.widget = invalid
				
				return "HANDLED"
				
            else if event["EventType"] = "EXIT_SIGNAL" then

                m.bsp.diagnostics.PrintDebug(m.id$ + ": exit signal")
            
            endif
            
        endif
        
	endif

    stateData.nextState = m.superState
    return "SUPER"

End Function

'endregion
	
'region Ticker State Machine
' *************************************************
'
' Ticker State Machine
'
' *************************************************
Function newTickerZoneHSM(bsp As Object, sign As Object, zoneXML As Object) As Object

    zoneHSM = newHSM()
	zoneHSM.ConstructorHandler = TickerZoneConstructor
	zoneHSM.InitialPseudostateHandler = TickerZoneGetInitialState

    newZoneCommon(bsp, zoneXML, zoneHSM)
    
    zoneHSM.rssDownloadPeriodicValue% = sign.rssDownloadPeriodicValue%
    zoneHSM.rssDownloadTimer = CreateObject("roTimer")

    zoneHSM.numberOfLines% = int(val(zoneXML.zoneSpecificParameters.textWidget.numberOfLines.GetText()))
    zoneHSM.delay% = int(val(zoneXML.zoneSpecificParameters.textWidget.delay.GetText()))
    
    ' below line doesn't work in BS2.0
    ' rotation$ = zoneXML.zoneSpecificParameters.textWidget.rotation.GetText()
	zoneHSM.rotation% = 0
    ele = zoneXML.zoneSpecificParameters.textWidget.GetNamedElements("rotation")
    if ele.Count() = 1 then
		rotation$ = ele[0].GetText()
		if rotation$ = "90" then
			zoneHSM.rotation% = 3
		else if rotation$ = "180" then
			zoneHSM.rotation% = 2
		else if rotation$ = "270" then
			zoneHSM.rotation% = 1
		endif
    endif
    
    alignment$ = zoneXML.zoneSpecificParameters.textWidget.alignment.GetText()
    if alignment$ = "center" then
        zoneHSM.alignment% = 1
    else if alignment$ = "right" then
        zoneHSM.alignment% = 2
    else
        zoneHSM.alignment% = 0
    endif
    
    zoneHSM.scrollingMethod% = int(val(zoneXML.zoneSpecificParameters.textWidget.scrollingMethod.GetText()))
    
    widget = zoneXML.zoneSpecificParameters.widget
    foregroundTextColor = widget.foregroundTextColor
    zoneHSM.foregroundTextColor% = GetColor(foregroundTextColor.GetAttributes())
    backgroundTextColor = widget.backgroundTextColor
    zoneHSM.backgroundTextColor% = GetColor(backgroundTextColor.GetAttributes())
    zoneHSM.font$ = widget.font.GetText()

    backgroundBitmap = widget.backgroundBitmap
    if backgroundBitmap.Count() = 1 then
        backgroundBitmapAttrs = backgroundBitmap.GetAttributes()
        zoneHSM.backgroundBitmapFile$ = backgroundBitmapAttrs["file"]
        stretchStr = backgroundBitmapAttrs["stretch"]
        if stretchStr = "true" then
            zoneHSM.stretch% = 1
        else
            zoneHSM.stretch% = 0
        endif
    endif
    
    safeTextRegion = widget.safeTextRegion
    if safeTextRegion.Count() = 1 then
        zoneHSM.safeTextRegionX% = int(val(safeTextRegion.safeTextRegionX.GetText()))
        zoneHSM.safeTextRegionY% = int(val(safeTextRegion.safeTextRegionY.GetText()))
        zoneHSM.safeTextRegionWidth% = int(val(safeTextRegion.safeTextRegionWidth.GetText()))
        zoneHSM.safeTextRegionHeight% = int(val(safeTextRegion.safeTextRegionHeight.GetText()))
    endif
    
    zoneHSM.stRSSDataFeedInitialLoad = zoneHSM.newHState(bsp, "RSSDataFeedInitialLoad")
    zoneHSM.stRSSDataFeedInitialLoad.HStateEventHandler = STRSSDataFeedInitialLoadEventHandler
	zoneHSM.stRSSDataFeedInitialLoad.superState = zoneHSM.stTop
        
    zoneHSM.stRSSDataFeedPlaying = zoneHSM.newHState(bsp, "RSSDataFeedPlaying")
	zoneHSM.stRSSDataFeedPlaying.PopulateRSSDataFeedWidget = PopulateRSSDataFeedWidget
    zoneHSM.stRSSDataFeedPlaying.HStateEventHandler = STRSSDataFeedPlayingEventHandler
	zoneHSM.stRSSDataFeedPlaying.superState = zoneHSM.stTop
			    	
    return zoneHSM
        
End Function


Sub TickerZoneConstructor()

	m.InitializeZoneCommon(m.bsp.msgPort)
	
    zoneHSM = m
    
    a=CreateObject("roAssociativeArray")
    a["PauseTime"] = zoneHSM.delay%
    a["Rotation"] = zoneHSM.rotation%
    a["Alignment"] = zoneHSM.alignment%

    textWidget = CreateObject("roTextWidget", zoneHSM.rectangle, zoneHSM.numberOfLines%, zoneHSM.scrollingMethod%, a)

    zoneHSM.widget = textWidget
    
    if type(zoneHSM.foregroundTextColor%) = "roInt" then
        zoneHSM.widget.SetForegroundColor(zoneHSM.foregroundTextColor%)
    endif
    
    if type(zoneHSM.backgroundTextColor%) = "roInt" then
        zoneHSM.widget.SetBackgroundColor(zoneHSM.backgroundTextColor%)
    endif
    
    if zoneHSM.font$ <> "" and zoneHSM.font$ <> "System" then
        fontPath$ = GetPoolFilePath(m.bsp.syncPoolFiles, zoneHSM.font$)
        zoneHSM.widget.SetFont(fontPath$)
    endif
            
    if IsString(zoneHSM.backgroundBitmapFile$) then
        backgroundBitmapFilePath$ = GetPoolFilePath(m.bsp.syncPoolFiles, zoneHSM.backgroundBitmapFile$)
        zoneHSM.widget.SetBackgroundBitmap(backgroundBitmapFilePath$, zoneHSM.stretch%)
    endif
            
    if type(zoneHSM.safeTextRegionX%) = "roInt" then
        r = CreateObject("roRectangle", zoneHSM.safeTextRegionX%, zoneHSM.safeTextRegionY%, zoneHSM.safeTextRegionWidth%, zoneHSM.safeTextRegionHeight%)
        zoneHSM.widget.SetSafeTextRegion(r)
        r = invalid
    endif

	m.includesRSSFeeds = false
	for each rssDataFeedItem in m.rssDataFeedItems
		if rssDataFeedItem.isRSSFeed then
			m.includesRSSFeeds = true
		endif
	next

End Sub


Function TickerZoneGetInitialState() As Object

	if m.includesRSSFeeds then
		return m.stRSSDataFeedInitialLoad
	else
		return m.stRSSDataFeedPlaying
	endif

End Function


Function GetRSSTempFilename()
	fileName$ = "tmp:/rss" + StripLeadingSpaces(stri(m.rssFileIndex%)) + ".xml"
	m.rssFileIndex% = m.rssFileIndex% + 1
	return fileName$
End Function


Function STRSSDataFeedInitialLoadEventHandler(event As Object, stateData As Object) As Object

    stateData.nextState = invalid
    
    if type(event) = "roAssociativeArray" then      ' internal message event

        if IsString(event["EventType"]) then
        
            if event["EventType"] = "ENTRY_SIGNAL" then
            
                m.bsp.diagnostics.PrintDebug(m.id$ + ": entry signal")

				for each rssDataFeedItem in m.stateMachine.rssDataFeedItems
					rssDataFeedItem.loadAttemptComplete = not rssDataFeedItem.isRSSFeed
				next

				return "HANDLED"

            else if event["EventType"] = "LIVE_DATA_FEED_UPDATE" or event["EventType"] = "LIVE_DATA_FEED_UPDATE_FAILURE" then

				liveDataFeed = event["EventData"]

				allLoadsComplete = true

				for each rssDataFeedItem in m.stateMachine.rssDataFeedItems
					if rssDataFeedItem.isRSSFeed then
						if liveDataFeed.name$ = rssDataFeedItem.liveDataFeed.name$ then
							rssDataFeedItem.loadAttemptComplete = true
						else if not rssDataFeedItem.loadAttemptComplete then
							allLoadsComplete = false
						endif
					endif
				next

				if allLoadsComplete then
					stateData.nextState = m.stateMachine.STRSSDataFeedPlaying
					return "TRANSITION"
				else
					return "HANDLED"
				endif

            else if event["EventType"] = "PREPARE_FOR_RESTART" then

                m.bsp.diagnostics.PrintDebug(m.id$ + " - PREPARE_FOR_RESTART")
				m.stateMachine.widget = invalid
				return "HANDLED"
				
			endif

		endif

	endif

    stateData.nextState = m.superState
    return "SUPER"

End Function


Sub PopulateRSSDataFeedWidget()

	' clear existing strings
	rssStringCount = m.stateMachine.widget.GetStringCount()
	m.stateMachine.widget.PopStrings(rssStringCount)

	' populate widget with new strings
	for each rssDataFeedItem in m.stateMachine.rssDataFeedItems
		if type(rssDataFeedItem.textStrings) = "roArray" then
			for each textString in rssDataFeedItem.textStrings
				m.stateMachine.widget.PushString(textString)
			next
		else
			for each article in rssDataFeedItem.liveDataFeed.articles
				m.stateMachine.widget.PushString(article)
			next
		endif
	next
				
	m.stateMachine.widget.Show()

End Sub


Function STRSSDataFeedPlayingEventHandler(event As Object, stateData As Object) As Object

    stateData.nextState = invalid
    
    if type(event) = "roAssociativeArray" then      ' internal message event

        if IsString(event["EventType"]) then
        
            if event["EventType"] = "ENTRY_SIGNAL" then
            
                m.bsp.diagnostics.PrintDebug(m.id$ + ": entry signal")

				m.PopulateRSSDataFeedWidget()

				return "HANDLED"

            else if event["EventType"] = "LIVE_DATA_FEED_UPDATE" then

				liveDataFeed = event["EventData"]

				' check that the live data feed is for one of the rss feeds

				rssDataFeedItemLoaded = false

				for each rssDataFeedItem in m.stateMachine.rssDataFeedItems
					if rssDataFeedItem.isRSSFeed then
						if liveDataFeed.name$ = rssDataFeedItem.liveDataFeed.name$ then
							rssDataFeedItemLoaded = true
							exit for
						endif
					endif
				next

				if rssDataFeedItemLoaded then

					m.PopulateRSSDataFeedWidget()

				endif

            else if event["EventType"] = "PREPARE_FOR_RESTART" then

                m.bsp.diagnostics.PrintDebug(m.id$ + " - PREPARE_FOR_RESTART")
				m.stateMachine.widget = invalid
				return "HANDLED"
				
			endif

		endif

	endif

    stateData.nextState = m.superState
    return "SUPER"

End Function

'endregion

'region Player State Machine
' *************************************************
'
' Player State Machine
'
' *************************************************
Function newPlayerStateMachine(bsp As Object) As Object

    PlayerStateMachine = newHSM()
    PlayerStateMachine.InitialPseudostateHandler = InitializePlayerStateMachine

	PlayerStateMachine.bsp = bsp
	PlayerStateMachine.msgPort = bsp.msgPort
	PlayerStateMachine.logging = bsp.logging
	
	PlayerStateMachine.SetSystemInfo = SetSystemInfo
	PlayerStateMachine.CheckForUSBUpdate = CheckForUSBUpdate
	PlayerStateMachine.DisplayUSBUpdateStatus = DisplayUSBUpdateStatus

    PlayerStateMachine.POOL_EVENT_FILE_DOWNLOADED = 1
    PlayerStateMachine.POOL_EVENT_FILE_FAILED = -1
    PlayerStateMachine.POOL_EVENT_ALL_DOWNLOADED = 2
    PlayerStateMachine.POOL_EVENT_ALL_FAILED = -2

    PlayerStateMachine.SYNC_ERROR_CANCELLED = -10001
    PlayerStateMachine.SYNC_ERROR_CHECKSUM_MISMATCH = -10002
    PlayerStateMachine.SYNC_ERROR_EXCEPTION = -10003
    PlayerStateMachine.SYNC_ERROR_DISK_ERROR = -10004
    PlayerStateMachine.SYNC_ERROR_POOL_UNSATISFIED = -10005
    
    PlayerStateMachine.EVENT_REALIZE_SUCCESS = 101

    PlayerStateMachine.stTop = PlayerStateMachine.newHState(bsp, "Top")
    PlayerStateMachine.stTop.HStateEventHandler = STTopEventHandler
    
    PlayerStateMachine.stPlayer = PlayerStateMachine.newHState(bsp, "Player") 
    PlayerStateMachine.stPlayer.HStateEventHandler = STPlayerEventHandler
	PlayerStateMachine.stPlayer.superState = PlayerStateMachine.stTop

    PlayerStateMachine.stPlaying = PlayerStateMachine.newHState(bsp, "Playing") 
    PlayerStateMachine.stPlaying.HStateEventHandler = STPlayingEventHandler
	PlayerStateMachine.stPlaying.superState = PlayerStateMachine.stPlayer
	PlayerStateMachine.stPlaying.RetrieveLiveDataFeed = RetrieveLiveDataFeed
	PlayerStateMachine.stPlaying.UpdateTimeClockEvents = UpdateTimeClockEvents

    PlayerStateMachine.stWaiting = PlayerStateMachine.newHState(bsp, "Waiting") 
    PlayerStateMachine.stWaiting.HStateEventHandler = STWaitingEventHandler
	PlayerStateMachine.stWaiting.superState = PlayerStateMachine.stPlayer

    PlayerStateMachine.stUpdatingFromUSB = PlayerStateMachine.newHState(bsp, "UpdatingFromUSB") 
    PlayerStateMachine.stUpdatingFromUSB.HStateEventHandler = STUpdatingFromUSBEventHandler
	PlayerStateMachine.stUpdatingFromUSB.superState = PlayerStateMachine.stPlayer
	PlayerStateMachine.stUpdatingFromUSB.BuildFileUpdateList = BuildFileUpdateList
    PlayerStateMachine.stUpdatingFromUSB.StartUpdateSyncListDownload = StartUpdateSyncListDownload
	PlayerStateMachine.stUpdatingFromUSB.HandleUSBSyncPoolEvent = HandleUSBSyncPoolEvent

    PlayerStateMachine.stWaitForStorageDetached = PlayerStateMachine.newHState(bsp, "WaitForStorageDetached")
    PlayerStateMachine.stWaitForStorageDetached.HStateEventHandler = STWaitForStorageDetachedEventHandler
	PlayerStateMachine.stWaitForStorageDetached.superState = PlayerStateMachine.stTop

	PlayerStateMachine.topState = PlayerStateMachine.stTop
	
	return PlayerStateMachine
	
End Function


Function InitializePlayerStateMachine() As Object

	m.bsp.Restart("")

	' determine if a battery charger is present
	m.powerManager = CreateObject("roPowerManager")
	s = m.powerManager.GetBatteryStatus()
	hwVersion = s.Lookup("hardware_version")
	if hwVersion = invalid then
        m.bsp.diagnostics.PrintDebug("No charger found")
		m.chargerPresent = false
	else
        m.bsp.diagnostics.PrintDebug("Charger found")
		m.chargerPresent = true

		m.powerManager.SetPowerSwitchMode("soft")
		m.powerManager.SetPort(m.msgPort)
		
		' get initial battery / charger state, save it, and log it
		m.powerSource$ = m.powerManager.GetPowerSource()
		batteryStatus = m.powerManager.GetBatteryStatus()

		m.batteryState$ = ""
		batteryState = batteryStatus.Lookup("state")
		if IsString(batteryState) then
			m.batteryState$ = batteryState
		endif
		
		m.socPercent$ = ""
		m.socPercentRange% = -1
		socPercent = batteryStatus.Lookup("soc_percent")
		if socPercent <> invalid then
			socPercentRange% = socPercent / 10
			m.socPercent$ = stri(socPercent)
			if m.socPercentRange% >= 10 then
				m.socPercentRange% = 9
			endif
			m.socPercentRange% = socPercentRange%
		endif
		
		m.bsp.diagnostics.PrintDebug("InitializePlayerStateMachine: Power Source = " + m.powerSource$ + ", Battery state = " + m.batteryState$ + ", soc percent = " + m.socPercent$)
		m.bsp.logging.WriteDiagnosticLogEntry(m.bsp.diagnosticCodes.EVENT_BATTERY_STATUS, m.powerSource$ + chr(9) + m.batteryState$ + chr(9) + m.socPercent$)
		if type(m.bsp.networkingHSM) = "roAssociativeArray" then
			m.bsp.networkingHSM.AddBatteryChargerItem("powerUp", m.powerSource$, m.batteryState$, m.socPercentRange%)
		endif
		
		m.batteryStatusTimer = CreateObject("roTimer")
		m.batteryStatusTimer.SetPort(m.msgPort)
		newTimeout = m.bsp.systemTime.GetLocalDateTime()
		newTimeout.AddMilliseconds(300000)
		m.batteryStatusTimer.SetDateTime(newTimeout)
		m.batteryStatusTimer.Start()
				
	endif
	
	' check for the presence of a USB drive with an update
	for n% = 1 to 9
		usb$ = "USB" + StripLeadingSpaces(stri(n%)) + ":"
		du = CreateObject("roStorageInfo", usb$)
		if type(du) = "roStorageInfo" then
			m.bsp.diagnostics.PrintDebug("### Disc mounted at " + usb$)
			if m.CheckForUSBUpdate(usb$) then
				m.storagePath$ = usb$
				return m.stUpdatingFromUSB
			endif
		endif
	next

	activeScheduledPresentation = m.bsp.schedule.activeScheduledEvent
	if type(activeScheduledPresentation) = "roAssociativeArray" then
	    return m.stPlaying
	else
	    return m.stWaiting
	endif

End Function


Function STPlayerEventHandler(event As Object, stateData As Object) As Object
    
    stateData.nextState = invalid
    
    if type(event) = "roAssociativeArray" then      ' internal message event

        if IsString(event["EventType"]) then
        
            if event["EventType"] = "ENTRY_SIGNAL" then
            
                m.bsp.diagnostics.PrintDebug(m.id$ + ": entry signal")
				
                return "HANDLED"

            else if event["EventType"] = "EXIT_SIGNAL" then

                m.bsp.diagnostics.PrintDebug(m.id$ + ": exit signal")
            
            else if event["EventType"] = "PREPARE_FOR_RESTART" then

                m.bsp.diagnostics.PrintDebug("STPlayerEventHandler - PREPARE_FOR_RESTART")

			    m.bsp.touchScreen = invalid

		        m.bsp.StopSignChannel()
                
                return "HANDLED"

			else if event["EventType"] = "SWITCH_PRESENTATION" then

				presentationName$ = event["Presentation"]

                m.bsp.diagnostics.PrintDebug("STPlayerEventHandler - Switch to presentation " + presentationName$)

				m.bsp.Restart(presentationName$)

				stateData.nextState = m.bsp.playerHSM.stPlaying

		        return "TRANSITION"

            else if event["EventType"] = "CONTENT_UPDATED" then

                ' new content was downloaded from the network
                
                m.bsp.diagnostics.PrintDebug("STPlayerEventHandler - CONTENT_UPDATED")

				currentSyncSpec = CreateObject("roSyncSpec")
	
				if currentSyncSpec.ReadFromFile("current-sync.xml") then
	
					m.bsp.syncPoolFiles = CreateObject("roSyncPoolFiles", "pool", currentSyncSpec)

				endif
				
				m.bsp.Restart("")
    
				activeScheduledPresentation = m.bsp.schedule.activeScheduledEvent
				if type(activeScheduledPresentation) = "roAssociativeArray" then
	    		    stateData.nextState = m.stateMachine.stPlaying
				else
	    		    stateData.nextState = m.stateMachine.stWaiting
				endif

		        return "TRANSITION"

            endif
            
        endif
        
    else if type(event) = "roPowerEvent" then
    
		powerData = event.GetData()
		currentState$ = "unknown"
		requestedState$ = "unknown"
		currentState = powerData.Lookup("current_state")
		if currentState <> invalid then
			currentState$ = currentState
		endif
		requestedState = powerData.Lookup("requested_state")
		if requestedState <> invalid then
			requestedState$ = requestedState
		endif
		
		if type(m.bsp.networkingHSM) = "roAssociativeArray" then
			m.bsp.networkingHSM.AddBatteryChargerItem("power down", "", "", -1)
		endif
		m.bsp.diagnostics.PrintDebug("STPlayerEventHandler: Power event received: current state = " + currentState$ + ", requested state = " + requestedState$)		
		m.bsp.logging.WriteDiagnosticLogEntry(m.bsp.diagnosticCodes.EVENT_POWER_EVENT, currentState$ + chr(9) + requestedState$)

		if requestedState$ = "S5" then
            m.bsp.logging.FlushLogFile()
            sleep(500)
			m.stateMachine.powerManager.PowerOff()
		endif
		
    else if type(event) = "roTimerEvent" then
		if type(m.stateMachine.timer) = "roTimer" and stri(event.GetSourceIdentity()) = stri(m.stateMachine.timer.GetIdentity()) then
			m.bsp.diagnostics.PrintDebug("STPlayerEventHandler timer event")
			
			' send internal message to prepare for restart
			prepareForRestartEvent = CreateObject("roAssociativeArray")
			prepareForRestartEvent["EventType"] = "PREPARE_FOR_RESTART"
			m.bsp.msgPort.PostMessage(prepareForRestartEvent)

			' send internal message indicating that new content is available
			contentUpdatedEvent = CreateObject("roAssociativeArray")
			contentUpdatedEvent["EventType"] = "CONTENT_UPDATED"
			m.bsp.msgPort.PostMessage(contentUpdatedEvent)
			
			return "HANDLED"
		endif
			
		if type(m.stateMachine.batteryStatusTimer) = "roTimer" and stri(event.GetSourceIdentity()) = stri(m.stateMachine.batteryStatusTimer.GetIdentity()) then
			powerSource$ = m.stateMachine.powerManager.GetPowerSource()
			batteryStatus = m.stateMachine.powerManager.GetBatteryStatus()

			batteryState$ = ""
			batteryState = batteryStatus.Lookup("state")
			if IsString(batteryState) then
				batteryState$ = batteryState
			endif
			
			socPercent$ = ""
			socPercentRange% = -1
			socPercent = batteryStatus.Lookup("soc_percent")
			if socPercent <> invalid then
				socPercentRange% = socPercent / 10
				socPercent$ = stri(socPercent)
				if socPercentRange% >= 10 then
					socPercentRange% = 9
				endif
			endif

			if powerSource$ <> m.stateMachine.powerSource$ or batteryState$ <> m.stateMachine.batteryState$ or socPercentRange% < m.stateMachine.socPercentRange% then
				m.stateMachine.powerSource$ = powerSource$
				m.stateMachine.batteryState$ = batteryState$
				m.stateMachine.socPercent$ = socPercent$
				m.stateMachine.socPercentRange% = socPercentRange%
				m.bsp.diagnostics.PrintDebug("STPlayerEventHandler - charger data changed: Power Source = " + powerSource$ + ", Battery state = " + batteryState$ + ", soc percent = " + socPercent$)
				if type(m.bsp.networkingHSM) = "roAssociativeArray" then
					m.bsp.networkingHSM.AddBatteryChargerItem("powerManagerStatus", powerSource$, batteryState$, socPercentRange%)
				endif
			endif
			
			m.bsp.diagnostics.PrintDebug("STPlayerEventHandler: Power Source = " + powerSource$ + ", Battery state = " + batteryState$ + ", soc percent = " + socPercent$)
			m.bsp.logging.WriteDiagnosticLogEntry(m.bsp.diagnosticCodes.EVENT_BATTERY_STATUS, powerSource$ + chr(9) + batteryState$ + chr(9) + socPercent$)

			newTimeout = m.bsp.systemTime.GetLocalDateTime()
			newTimeout.AddMilliseconds(15000)
			m.stateMachine.batteryStatusTimer.SetDateTime(newTimeout)
			m.stateMachine.batteryStatusTimer.Start()
			
			return "HANDLED"
		endif
		
        if type(m.bsp.logging.cutoverTimer) = "roTimer" then
        
            if stri(event.GetSourceIdentity()) = stri(m.bsp.logging.cutoverTimer.GetIdentity()) then

				m.bsp.diagnostics.PrintDebug("STPlayerEventHandler cutover logs timer event")

				m.bsp.logging.HandleTimerEvent()
				                
				m.bsp.LogActivePresentation()

                return "HANDLED"
                
            endif
            
        endif
		
	else if type(event) = "roHdmiEdidChanged" then

		edid = m.bsp.videoMode.GetEdidIdentity(true)
		UpdateEdidValues(edid, m.bsp.sysInfo)
		edid = invalid

		m.bsp.UpdateEdidUserVariables(true)

		systemVariableChanged = CreateObject("roAssociativeArray")
		systemVariableChanged["EventType"] = "SYSTEM_VARIABLE_UPDATED"
		m.bsp.msgPort.PostMessage(systemVariableChanged)
			
    else if type(event) = "roUrlEvent" then
    
		if type(m.bsp.feedVideoDownloader) = "roAssociativeArray" then
			if event.GetSourceIdentity() = m.bsp.feedVideoDownloader.videoDownloader.GetIdentity() then
				m.bsp.feedVideoDownloader.HandleUrlEvent(event, m.bsp.feedPlayer)
			endif
		endif
	
	else if type(event) = "roNetworkAttached" or type(event) = "roNetworkDetached" then
	
		networkInterface% = event.GetInt()

		if type(event) = "roNetworkAttached" then
			nc = CreateObject("roNetworkConfiguration", networkInterface%)
			if type(nc) = "roNetworkConfiguration" then
				currentConfig = nc.GetCurrentConfig()
				if type(currentConfig) = "roAssociativeArray" then
					if currentConfig.ip4_address <> "" then
						if networkInterface% = 0 then
							m.bsp.sysInfo.ipAddressWired$ = currentConfig.ip4_address
						else if networkInterface% = 1 then
							m.bsp.sysInfo.ipAddressWireless$ = currentConfig.ip4_address
						endif
					endif
				endif
			endif
			nc = invalid
		else
			if networkInterface% = 0 then
				m.bsp.sysInfo.ipAddressWired$ = "Invalid"
			else if networkInterface% = 1 then
				m.bsp.sysInfo.ipAddressWireless$ = "Invalid"
			endif
		endif

		m.bsp.UpdateIPAddressUserVariables(true)

		systemVariableChanged = CreateObject("roAssociativeArray")
		systemVariableChanged["EventType"] = "SYSTEM_VARIABLE_UPDATED"
		m.bsp.msgPort.PostMessage(systemVariableChanged)			

	else if type(event) = "roControlEvent" then
		
		eventIdentity = stri(event.GetSourceIdentity())

		blcIndex% = -1
		if type(m.bsp.blcDiagnostics[0]) = "roControlPort" and stri(m.bsp.blcDiagnostics[0].GetIdentity()) = eventIdentity then
			blcIndex% = 0
		else if type(m.bsp.blcDiagnostics[1]) = "roControlPort" and stri(m.bsp.blcDiagnostics[1].GetIdentity()) = eventIdentity then
			blcIndex% = 1
		else if type(m.bsp.blcDiagnostics[2]) = "roControlPort" and stri(m.bsp.blcDiagnostics[2].GetIdentity()) = eventIdentity then
			blcIndex% = 2
		endif

		if blcIndex% <> -1 then
			blcIdentifier$ = "BLC" + stri(blcIndex%) + ":"
		endif

		' event types coming back from the blc400
		REPORT_UNDER_EVENT%      = &h20
		REPORT_OVER_EVENT%       = &h21
		REPORT_MISSING%          = &h22
		REPORT_NORMAL%           = &h23

		' event ADC channels
		MAIN_ADC%        = 0
		LED_ADC_COMP1%   = 1
		LED_ADC_COMP2%   = 2
		LED_ADC_COMP3%   = 3
		LED_ADC_COMP4%   = 4
		LED_ADC_OCOMP1%  = 5
		LED_ADC_OCOMP2%  = 6
		LED_ADC_OCOMP3%  = 7
		LED_ADC_OCOMP4%  = 8

		ch% = event.GetEventByte(1)
		adc% = event.GetEventWord(2)

		if (event.GetEventByte(0) = REPORT_UNDER_EVENT%) then
			event$ = "REPORT_UNDER_EVENT: "
		else if (event.GetEventByte(0) = REPORT_OVER_EVENT%) then
			event$ = "REPORT_OVER_EVENT: "
		else if (event.GetEventByte(0) = REPORT_MISSING%) then
			event$ = "REPORT_MISSING: "
		else if (event.GetEventByte(0) = REPORT_NORMAL%) then
			event$ = "REPORT_NORMAL: "
		else
			event$ = ""
		endif

		nextChannel% = -1

		if event$ = "" then
			msg$ = blcIdentifier$ + "Unexpected control event(0): " + Stri(event.GetEventByte(0))
		else if (ch% = MAIN_ADC%) then
			msg$ = blcIdentifier$ + event$ + "Main Power: " + Stri(adc%)
			nextChannel% = &h01
		else if (ch% = LED_ADC_COMP1%) or (ch% = LED_ADC_OCOMP1%) then
			msg$ = blcIdentifier$ + event$ + "Channel A: " + Stri(adc%)
			nextChannel% = &h02
		else if (ch% = LED_ADC_COMP2%) or (ch% = LED_ADC_OCOMP2%) then
			msg$ = blcIdentifier$ + event$ + "Channel B: " + Stri(adc%)
			nextChannel% = &h04
		else if (ch% = LED_ADC_COMP3%) or (ch% = LED_ADC_OCOMP3%) then
			msg$ = blcIdentifier$ + event$ + "Channel C: " + Stri(adc%)
			nextChannel% = &h08
		else if (ch% = LED_ADC_COMP4%) or (ch% = LED_ADC_OCOMP4%) then
			msg$ = blcIdentifier$ + event$ + "Channel D: " + Stri(adc%)
		else
			msg$ = blcIdentifier$ + "Unknown Power Error: " + Stri(ch%) + ": " + Stri(adc%)
		endif

		m.bsp.diagnostics.PrintDebug(msg$)
        m.bsp.logging.WriteDiagnosticLogEntry(m.bsp.diagnosticCodes.EVENT_BLC400_STATUS, msg$)

		if nextChannel% <> -1 and blcIndex% <> -1 then
			m.bsp.CheckBLCStatus(m.bsp.blcs[blcIndex%], nextChannel%)
		endif

	else if type(event) = "roStorageAttached" then

		storagePath$ = event.GetString()

		' check for existence of upgrade file
		if m.stateMachine.CheckForUSBUpdate(storagePath$) then

			m.stateMachine.storagePath$ = storagePath$
			stateData.nextState = m.stateMachine.stUpdatingFromUSB
			return "TRANSITION"

		else
			actionsXMLFilePath$ = event.GetString() + "actions.xml"

			actionsSpec$ = ReadAsciiFile(actionsXMLFilePath$)
			if actionsSpec$ <> "" then

		        actionsXML = CreateObject("roXMLElement")
				actionsXML.Parse(actionsSpec$)

				if type(actionsXML.action) = "roXMLList" then

					if actionsXML.action.Count() > 0 then
					
						attributes = actionsXML.GetAttributes()
						displayStatus$ = attributes.Lookup("displayStatus")
						if lcase(displayStatus$) = "true" then

							videoMode = CreateObject("roVideoMode")
							resX = videoMode.GetResX()
							resY = videoMode.GetResY()
							videoMode = invalid

							r = CreateObject("roRectangle", 0, 0, resX, resY)
							twParams = CreateObject("roAssociativeArray")
							twParams.LineCount = 1
							twParams.TextMode = 2
							twParams.Rotation = 0
							twParams.Alignment = 1
							tw=CreateObject("roTextWidget",r,1,2,twParams)
							tw.PushString("")
							tw.Show()

							r=CreateObject("roRectangle",0,resY/2-resY/64,resX,resY/32)
							tw=CreateObject("roTextWidget",r,1,2,twParams)

							displayStatus = true

						else

							displayStatus = false
						
						endif

						deletedLogFiles = false

						errorEncountered = false

						for each action in actionsXML.action

							action$ = action.GetText()

							if action$ = "copyLogs" then

								if displayStatus then
									tw.Clear()
									tw.PushString("Copying log files.")
									tw.Show()
								endif

								ok = m.bsp.logging.CopyAllLogFiles(storagePath$)
								if ok then
									m.bsp.diagnostics.PrintDebug("CopyAllLogFiles completed successfully")
								else
									errorEncountered = true
									m.bsp.diagnostics.PrintDebug("CopyAllLogFiles failed")

									if displayStatus then

										tw.Clear()
										tw.PushString("Error encountered while copying log files.")
										tw.Show()

										sleep(5000)

									endif

									exit for
								endif

							else if action$ = "deleteLogs" then

								if displayStatus then
									tw.Clear()
									tw.PushString("Deleting log files.")
									tw.Show()
								endif

								m.bsp.logging.DeleteAllLogFiles()
								m.bsp.diagnostics.PrintDebug("DeleteAllLogFiles complete")
								deletedLogFiles = true

							else if action$ = "resetVariables" then

								if displayStatus then
									tw.Clear()
									tw.PushString("Resetting variables.")
									tw.Show()
								endif

								m.bsp.ResetVariables()

								m.bsp.diagnostics.PrintDebug("Resetting variables complete")

							else if action$ = "copyVariablesDB" then

								if m.bsp.variablesDBExists then

									if displayStatus then
										tw.Clear()
										tw.PushString("Copying variables database.")
										tw.Show()
									endif

									serialNumber$ = m.bsp.sysInfo.deviceUniqueID$

									dtLocal = m.bsp.systemTime.GetLocalDateTime()
									year$ = Right(stri(dtLocal.GetYear()), 2)
									month$ = StripLeadingSpaces(stri(dtLocal.GetMonth()))
									if len(month$) = 1 then
										month$ = "0" + month$
									endif
									day$ = StripLeadingSpaces(stri(dtLocal.GetDay()))
									if len(day$) = 1 then
										day$ = "0" + day$
									endif
									hour$ = StripLeadingSpaces(stri(dtLocal.GetHour()))
									if len(hour$) = 1 then
										hour$ = "0" + day$
									endif
									minute$ = StripLeadingSpaces(stri(dtLocal.GetMinute()))
									if len(minute$) = 1 then
										minute$ = "0" + minute$
									endif
	'								date$ = year$ + month$ + day$ + hour$ + minute$
									date$ = year$ + month$ + day$

									fileName$ = "BrightSignVariables." + serialNumber$ + "-" + date$ + ".txt"
									filePath$ = storagePath$ + fileName$

									variablesFile = CreateObject("roCreateFile", filePath$)
									
									if type(variablesFile) = "roCreateFile" then

										m.bsp.ExportVariablesDBToAsciiFile(variablesFile)

										' determine if write was successful
										' partial fix - only works if card was full before this step
										variablesFile.SeekToEnd()
										position% = variablesFile.CurrentPosition()
										if position% = 0 then
											errorEncountered = true
											m.bsp.diagnostics.PrintDebug("copyVariablesDB failed - fileLength = 0")
										else
											m.bsp.diagnostics.PrintDebug("Wrote variables file to " + filePath$)
										endif

										variablesFile = invalid

									else

										errorEncountered = true
										m.bsp.diagnostics.PrintDebug("copyVariablesDB failed - create file failed")

									endif

									if errorEncountered then

										if displayStatus then

											tw.Clear()
											tw.PushString("Error encountered while copying variables database.")
											tw.Show()

											sleep(5000)

										endif

										exit for

									endif

								else if displayStatus then

									tw.Clear()
									tw.PushString("No variables to copy.")
									tw.Show()

									sleep(3000)

								endif
							
							else if action$ = "reboot" then

								if displayStatus then
									tw.Clear()
									tw.PushString("Finalizing data writes, do not remove your drive yet.")
									tw.Show()

									EjectStorage(storagePath$)

									tw.Clear()
									tw.PushString("Data capture complete - you may remove your drive. The system will reboot shortly.")
									tw.Show()

									sleep(5000)
									tw.Clear()
								else
									EjectStorage(storagePath$)
								endif

								RebootSystem()

								return "HANDLED"

							endif
						next

						if displayStatus then

							tw.Clear()
							tw.PushString("Finalizing data writes, do not remove your drive yet.")
							tw.Show()

							EjectStorage(storagePath$)

							tw.Clear()

							if errorEncountered then
								tw.PushString("Data capture failed  - you may remove your drive.")
							else
								tw.PushString("Data capture completed successfully  - you may remove your drive.")
							endif

							tw.Show()

							sleep(5000)

							tw = invalid

						endif

						' if the log files were deleted but the system is not rebooting, open a log file
						if m.bsp.logging.loggingEnabled then m.bsp.logging.OpenOrCreateCurrentLog()

					endif
				endif
			endif
		endif
	endif

    stateData.nextState = m.superState
    return "SUPER"

End Function


Sub EjectStorage(storagePath$ As String)

	ok = EjectDrive(storagePath$)
	if not ok then
		sleep(30000)
	endif

End Sub


Function STWaitingEventHandler(event As Object, stateData As Object) As Object

    stateData.nextState = invalid
    
    if type(event) = "roAssociativeArray" then      ' internal message event

        if IsString(event["EventType"]) then
        
            if event["EventType"] = "ENTRY_SIGNAL" then
            
                m.bsp.diagnostics.PrintDebug(m.id$ + ": entry signal")

				' set a timer for when the system should become active again
				if type(m.bsp.schedule.nextScheduledEventTime) = "roDateTime" then
					dateTime = m.bsp.schedule.nextScheduledEventTime
					newTimer = CreateObject("roTimer")
					newTimer.SetTime(dateTime.GetHour(), dateTime.GetMinute(), 0)
					newTimer.SetDate(dateTime.GetYear(), dateTime.GetMonth(), dateTime.GetDay())
					newTimer.SetDayOfWeek(dateTime.GetDayOfWeek())
					newTimer.SetPort(m.stateMachine.msgPort)
					newTimer.Start()
		            m.stateMachine.timer = newTimer
				endif
				
                return "HANDLED"

            else if event["EventType"] = "EXIT_SIGNAL" then

                m.bsp.diagnostics.PrintDebug(m.id$ + ": exit signal")
            
            endif
            
        endif
        
    endif
            
    stateData.nextState = m.superState
    return "SUPER"
    
End Function


Function STPlayingEventHandler(event As Object, stateData As Object) As Object

    stateData.nextState = invalid
    
    if type(event) = "roAssociativeArray" then      ' internal message event

        if IsString(event["EventType"]) then
        
            if event["EventType"] = "ENTRY_SIGNAL" then
            
                m.bsp.diagnostics.PrintDebug(m.id$ + ": entry signal")

				' set a timer for when the current presentation should end
				activeScheduledPresentation = m.bsp.schedule.activeScheduledEvent
			    
				if type(activeScheduledPresentation) = "roAssociativeArray" then
			        
					if not activeScheduledPresentation.allDayEveryDay then
			        
						endDateTime = CopyDateTime(activeScheduledPresentation.dateTime)
						endDateTime.AddSeconds(activeScheduledPresentation.duration% * 60)

						newTimer = CreateObject("roTimer")
						newTimer.SetTime(endDateTime.GetHour(), endDateTime.GetMinute(), 0)
						newTimer.SetDate(endDateTime.GetYear(), endDateTime.GetMonth(), endDateTime.GetDay())
						newTimer.SetDayOfWeek(endDateTime.GetDayOfWeek())
						newTimer.SetPort(m.stateMachine.msgPort)
						newTimer.Start()
			                            
						m.stateMachine.timer = newTimer

						m.bsp.diagnostics.PrintDebug("Set STPlayingEventHandler timer to " + endDateTime.GetString())

					endif
					
					' load live data feeds associated with Live Text items
					m.liveDataFeeds = CreateObject("roAssociativeArray")
					m.liveDataFeedsByTimer = CreateObject("roAssociativeArray")
					for each liveDataFeedName in m.bsp.liveDataFeeds
						liveDataFeed = m.bsp.liveDataFeeds.Lookup(liveDataFeedName)
						m.RetrieveLiveDataFeed(liveDataFeed)
					next

					' launch playback
					m.bsp.StartPlayback()
					
				endif
				
                return "HANDLED"

            else if event["EventType"] = "EXIT_SIGNAL" then

                m.bsp.diagnostics.PrintDebug(m.id$ + ": exit signal")
            
            endif
            
        endif

    else if type(event) = "roTimerEvent" then
        
		eventIdentity$ = stri(event.GetSourceIdentity())

		if m.liveDataFeedsByTimer.DoesExist(eventIdentity$) then
			liveDataFeed = m.liveDataFeedsByTimer.Lookup(eventIdentity$)
			m.RetrieveLiveDataFeed(liveDataFeed)
		endif

		
    else if type(event) = "roUrlEvent" then

		eventIdentity$ = stri(event.GetSourceIdentity())

		if m.liveDataFeeds.DoesExist(eventIdentity$) then
			liveDataFeed = m.liveDataFeeds.Lookup(eventIdentity$)
			m.liveDataFeeds.Delete(eventIdentity$)
			if event.GetResponseCode() = 200 or event.GetResponseCode() = 0 then

				liveDataFeedDownloadFailed = false

				liveDataFeed.articles = CreateObject("roArray", 1, true)
				liveDataFeed.articleTitles = CreateObject("roArray", 1, true)
				liveDataFeed.articlesByTitle = CreateObject("roAssociativeArray")

				userVariables = invalid
				if type(m.bsp.userVariableSets) = "roAssociativeArray" then
					userVariables = m.bsp.userVariableSets.Lookup(m.bsp.activePresentation$)
				endif

				parser$ = liveDataFeed.parser$
				if parser$ <> "" then
					ERR_NORMAL_END = &hFC
					retVal = Eval(liveDataFeed.parser$ + "(liveDataFeed.rssFileName$, liveDataFeed.articles, liveDataFeed.articlesByTitle, userVariables)")
					if retVal <> ERR_NORMAL_END then
						' log the failure
		                m.bsp.diagnostics.PrintDebug("Failure invoking Eval to parse live text data feed: return value = " + stri(retVal) + ", parser is " + liveDataFeed.parser$)
				        m.bsp.logging.WriteDiagnosticLogEntry(m.bsp.diagnosticCodes.EVENT_LIVE_TEXT_PLUGIN_FAILURE, stri(retVal) + chr(9) + liveDataFeed.parser$)
					endif
				else
					if type(liveDataFeed.isJSON) = "roBoolean" and liveDataFeed.isJSON then
						jsonString=ReadAsciiFile(liveDataFeed.rssFileName$)
						json = ParseJSON(jsonString)
						for each jsonItem in json
							text$ = jsonItem.text
							liveDataFeed.articles.Push(text$)
							liveDataFeed.articleTitles.Push(text$)
							liveDataFeed.articlesByTitle.AddReplace(text$, text$)
						next
					else
						parser = CreateObject("roRssParser")
						parser.ParseFile(liveDataFeed.rssFileName$)
						article = parser.GetNextArticle()
						while type(article) = "roRssArticle"
							title = article.GetTitle()
							description = article.GetDescription()
							liveDataFeed.articles.Push(description)
							liveDataFeed.articleTitles.Push(title)
							liveDataFeed.articlesByTitle.AddReplace(title, description)
							article = parser.GetNextArticle()
						endwhile
					endif
				endif

				DeleteFile(liveDataFeed.rssFileName$)

				' update user variables
				if type(userVariables) = "roAssociativeArray" then

					updatedUserVariables = { }

					for each title in liveDataFeed.articlesByTitle
						' update user variable if appropriate
						if userVariables.DoesExist(title) then
							userVariable = userVariables.Lookup(title)
							if type(userVariable.liveDataFeed) = "roAssociativeArray" and userVariable.liveDataFeed.name$ = liveDataFeed.name$ then
								description = liveDataFeed.articlesByTitle[title]
								userVariable.SetCurrentValue(description, true)
								updatedUserVariables.AddReplace(title, userVariable)
							endif
						endif
					next

					m.UpdateTimeClockEvents(updatedUserVariables)

				endif

				' send internal message indicating that the data feed has been updated
				liveTextDataUpdatedEvent = CreateObject("roAssociativeArray")
				liveTextDataUpdatedEvent["EventType"] = "LIVE_DATA_FEED_UPDATE"
				liveTextDataUpdatedEvent["EventData"] = liveDataFeed
				m.bsp.msgPort.PostMessage(liveTextDataUpdatedEvent)

			else
				liveDataFeedDownloadFailed = true
				url$ = liveDataFeed.url.GetCurrentParameterValue()
                m.bsp.diagnostics.PrintDebug("Failure downloading Live Text Data feed " + url$ + ", responseCode = " + stri(event.GetResponseCode()))
		        m.bsp.logging.WriteDiagnosticLogEntry(m.bsp.diagnosticCodes.EVENT_LIVE_TEXT_FEED_DOWNLOAD_FAILURE, url$ + chr(9) + stri(event.GetResponseCode()) + chr(9) + event.GetFailureReason())
			
				' send internal message indicating that the data feed download failed
				liveTextDataUpdatedEvent = CreateObject("roAssociativeArray")
				liveTextDataUpdatedEvent["EventType"] = "LIVE_DATA_FEED_UPDATE_FAILURE"
				liveTextDataUpdatedEvent["EventData"] = liveDataFeed
				m.bsp.msgPort.PostMessage(liveTextDataUpdatedEvent)
			
			endif

			' set a timer to update live data feed
			if type(liveDataFeed.timer) <> "roTimer" then
				liveDataFeed.timer = CreateObject("roTimer")
				liveDataFeed.timer.SetPort(m.bsp.msgPort)
			endif

			newTimeout = m.bsp.systemTime.GetLocalDateTime()
			if liveDataFeedDownloadFailed then
				newTimeout.AddSeconds(30)
			else
				newTimeout.AddSeconds(liveDataFeed.updateInterval%)
			endif
			liveDataFeed.timer.SetDateTime(newTimeout)
			liveDataFeed.timer.Start()

			m.liveDataFeedsByTimer.AddReplace(stri(liveDataFeed.timer.GetIdentity()), liveDataFeed)

		endif
		
    endif
            
    stateData.nextState = m.superState
    return "SUPER"
    
End Function


Function STUpdatingFromUSBEventHandler(event As Object, stateData As Object) As Object

    stateData.nextState = invalid
    
    if type(event) = "roAssociativeArray" then      ' internal message event

        if IsString(event["EventType"]) then
        
            if event["EventType"] = "ENTRY_SIGNAL" then
            
                m.bsp.diagnostics.PrintDebug(m.id$ + ": entry signal")

' stop all playback, clear screen and background
				if type(m.bsp.sign) = "roAssociativeArray" and type(m.bsp.sign.zonesHSM) = "roArray" then
					for each zoneHSM in m.bsp.sign.zonesHSM

						if IsAudioPlayer(zoneHSM.audioPlayer) then
							zoneHSM.audioPlayer.Stop()
							zoneHSM.audioPlayer = invalid
						endif

						if type(zoneHSM.videoPlayer) = "roVideoPlayer" then
							zoneHSM.videoPlayer.Stop()
							zoneHSM.videoPlayer = invalid
						endif

						zoneHSM.ClearImagePlane()

						zoneHSM.StopSignChannelInZone()

					next
				endif

				m.bsp.sign = invalid

				videoMode = CreateObject("roVideoMode")
				resX = videoMode.GetResX()
				resY = videoMode.GetResY()
				videoMode.SetBackgroundColor(0)                     
				videoMode = invalid

' display update message on the screen
				twParams = CreateObject("roAssociativeArray")
				twParams.LineCount = 1
				twParams.TextMode = 2
				twParams.Rotation = 0
				twParams.Alignment = 1

				r=CreateObject("roRectangle",0,resY/2-resY/64,resX,resY/32)
				m.stateMachine.usbUpdateTW = CreateObject("roTextWidget",r,1,2,twParams)

				m.stateMachine.DisplayUSBUpdateStatus("Content update in progress. Do not remove the drive.")

' read the sync specs and proceed with update if appropriate
				syncSpecFilePath$ = m.stateMachine.storagePath$ + "/update/local-sync.xml"

				m.stateMachine.newSync = CreateObject("roSyncSpec")
				ok = m.stateMachine.newSync.ReadFromFile(syncSpecFilePath$)
				if not ok then
					m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_READ_SYNCSPEC_FAILURE, "newSync")
					m.bsp.diagnostics.PrintDebug("### USB drive has an invalid sync spec.")
					usbUpdateErrorEvent = CreateObject("roAssociativeArray")
					usbUpdateErrorEvent["EventType"] = "USB_UPDATE_ERROR"
					usbUpdateErrorEvent["Message"] = "Update files are corrupt."
					m.stateMachine.msgPort.PostMessage(usbUpdateErrorEvent)
					return "HANDLED"
				endif

' perform security check
				usbContentUpdatePassword$ = m.bsp.registrySettings.usbContentUpdatePassword$

				' check for signature file
				signaturePath$ = m.stateMachine.storagePath$ + "/update/signature.txt"
				signatureFile = CreateObject("roReadFile", signaturePath$)
				if type(signatureFile) = "roReadFile" then
					signatureFileExists = true
					signature$ = ReadAsciiFile(signaturePath$)
				else
					signatureFileExists = false
				endif
				signatureFile = invalid

				securityError = false

				if not signatureFileExists then
					' no signature file and passphrase => error; no signature file and no passphrase => proceed with update
					if usbContentUpdatePassword$ <> "" then
						securityError = true
					endif
				else if usbContentUpdatePassword$ <> "" then
					ok = m.stateMachine.newSync.VerifySignature(signature$, usbContentUpdatePassword$)
					if not ok then
						securityError = true
					endif
				endif

				if securityError then
					m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_USB_UPDATE_SECURITY_ERROR, "local-sync")
					m.bsp.diagnostics.PrintDebug("### USB update security error.")
					usbUpdateErrorEvent = CreateObject("roAssociativeArray")
					usbUpdateErrorEvent["EventType"] = "USB_UPDATE_ERROR"
					usbUpdateErrorEvent["Message"] = "Update failed - an incorrect password was provided."
					m.stateMachine.msgPort.PostMessage(usbUpdateErrorEvent)
					return "HANDLED"
				endif

			    m.stateMachine.currentSync = CreateObject("roSyncSpec")
				if not m.stateMachine.currentSync.ReadFromFile("local-sync.xml") then
					m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_READ_SYNCSPEC_FAILURE, "local-sync")
					m.bsp.diagnostics.PrintDebug("### Unable to read local-sync.xml.")
					usbUpdateErrorEvent = CreateObject("roAssociativeArray")
					usbUpdateErrorEvent["EventType"] = "USB_UPDATE_ERROR"
					usbUpdateErrorEvent["Message"] = "Unable to perform update."
					m.stateMachine.msgPort.PostMessage(usbUpdateErrorEvent)
					return "HANDLED"
				endif

				if m.stateMachine.newSync.EqualTo(m.stateMachine.currentSync) then
					m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_SYNCSPEC_RECEIVED, "NO")
					m.bsp.diagnostics.PrintDebug("### USB drive has a spec that matches current-sync. Nothing more to do.")
					m.stateMachine.newSync = invalid

					updateSyncSpecMatchesEvent = CreateObject("roAssociativeArray")
					updateSyncSpecMatchesEvent["EventType"] = "UPDATE_SYNC_SPEC_MATCHES"
					m.stateMachine.msgPort.PostMessage(updateSyncSpecMatchesEvent)
					return "HANDLED"
				endif

		        m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_SYNCSPEC_RECEIVED, "YES")

				m.BuildFileUpdateList(m.stateMachine.newSync)

                errorMsg = m.StartUpdateSyncListDownload()
				if type(errorMsg) = "roString" then
					usbUpdateErrorEvent = CreateObject("roAssociativeArray")
					usbUpdateErrorEvent["EventType"] = "USB_UPDATE_ERROR"
					usbUpdateErrorEvent["Message"] = errorMsg
					m.stateMachine.msgPort.PostMessage(usbUpdateErrorEvent)
				endif

				return "HANDLED"

            else if event["EventType"] = "EXIT_SIGNAL" then

                m.bsp.diagnostics.PrintDebug(m.id$ + ": exit signal")
            
            else if event["EventType"] = "UPDATE_SYNC_SPEC_MATCHES" then

				m.stateMachine.waitForStorageDetachedMsg$ = "The content on the USB drive matches the content on the card. Remove the drive and the system will reboot."
	            stateData.nextState = m.stateMachine.stWaitForStorageDetached
				return "TRANSITION"

            else if event["EventType"] = "USB_UPDATE_ERROR" then

				errorMsg$ = event["Message"]

				m.stateMachine.waitForStorageDetachedMsg$ = errorMsg$ + " Remove the drive and the system will reboot."
	            stateData.nextState = m.stateMachine.stWaitForStorageDetached
				return "TRANSITION"

            else if event["EventType"] = "PREPARE_FOR_RESTART" or event["EventType"] = "SWITCH_PRESENTATION" or event["EventType"] = "CONTENT_UPDATED" then ' consume these events during USB updates

				return "HANDLED"

            endif
            
        endif

    else if type(event) = "roTimerEvent" or type(event) = "roUrlEvent" then	' consume these events during USB updates

		return "HANDLED"

    else if type(event) = "roSyncPoolProgressEvent" then

		m.bsp.diagnostics.PrintDebug("### File update progress " + event.GetFileName() + str(event.GetCurrentFilePercentage()))

		m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_FILE_DOWNLOAD_PROGRESS, event.GetFileName() + chr(9) + str(event.GetCurrentFilePercentage()))

		fileIndex% = event.GetFileIndex()
		fileItem = m.stateMachine.newSync.GetFile("download", fileIndex%)

		if event.GetCurrentFilePercentage() = 0 then
			m.stateMachine.DisplayUSBUpdateStatus("Downloading " + event.GetFileName() + " (" + StripLeadingSpaces(stri(fileIndex%)) + " of " + StripLeadingSpaces(stri(m.listOfUpdateFiles.Count())) + "). Do not remove the drive.")
		endif

        return "HANDLED"
        
    else if (type(event) = "roSyncPoolEvent") then
	    
	    if stri(event.GetSourceIdentity()) = stri(m.syncPool.GetIdentity()) then

	        nextState = m.HandleUSBSyncPoolEvent(event)
	        
            if type(nextState) = "roAssociativeArray" then
                stateData.nextState = nextState
	            return "TRANSITION"
            endif

            return "HANDLED"
            
	    endif

' this event is currently not received - the script gets the typical roSyncPoolEvent errors.	            
'	else if type(event) = "roStorageDetached" then

'		m.stateMachine.DisplayUSBUpdateStatus("The drive was removed before the update was complete - the system will reboot shortly.")
'		sleep(5000)
'	    RebootSystem()

    endif
            
    stateData.nextState = m.superState
    return "SUPER"
    
End Function


Sub BuildFileUpdateList(syncSpec As Object)

    fileInPoolStatus = CreateObject("roAssociativeArray")
	tmpSyncPool = CreateObject("roSyncPool", "pool")
	if type(tmpSyncPool) = "roSyncPool" then
        fileInPoolStatus = tmpSyncPool.QueryFiles(syncSpec)
    endif

    m.listOfUpdateFiles = CreateObject("roArray", 10, true)

	for each fileName in fileInPoolStatus
	
		fileInPool = fileInPoolStatus.Lookup(fileName)
		if not fileInPool then
			m.listOfUpdateFiles.push(fileName)
		endif

	next

End Sub


Function StartUpdateSyncListDownload() As Object

    m.bsp.diagnostics.PrintDebug("### Start usb update sync list download")
    m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_DOWNLOAD_START, "")

    m.syncPool = CreateObject("roSyncPool", "pool")
    m.syncPool.ReserveMegabytes(50) ' ensure there is sufficient space for logs, sync specs, etc.
    m.syncPool.SetPort(m.stateMachine.msgPort)
'    m.syncPool.SetFileProgressIntervalSeconds(-1) ' use default of 300 seconds

	if not m.syncPool.ProtectFiles(m.stateMachine.currentSync, 0) then ' don't allow download to delete current files
		m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_SYNCPOOL_PROTECT_FAILURE, m.syncPool.GetFailureReason())
		m.bsp.diagnostics.PrintDebug("### ProtectFiles failed: " + m.syncPool.GetFailureReason())
        return "Update failure (ProtectFiles)."
    endif

	prefix$ = "file:///" + m.stateMachine.storagePath$ + "/update/"
	m.syncPool.SetRelativeLinkPrefix(prefix$)

    if not m.syncPool.AsyncDownload(m.stateMachine.newSync) then
        m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_SYNCSPEC_DOWNLOAD_IMMEDIATE_FAILURE, m.syncPool.GetFailureReason())
        m.bsp.diagnostics.PrintDebug("### AsyncDownload failed: " + m.syncPool.GetFailureReason())
        return "Update failure (AsyncDownload)."
    endif

	return invalid

End Function


Function HandleUSBSyncPoolEvent(event As Object) As Object

    m.bsp.diagnostics.PrintTimestamp()
    m.bsp.diagnostics.PrintDebug("### usb update pool_event")

	if (event.GetEvent() = m.stateMachine.POOL_EVENT_FILE_DOWNLOADED) then
        m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_FILE_DOWNLOAD_COMPLETE, event.GetName())
        m.bsp.diagnostics.PrintDebug("### File downloaded " + event.GetName())
	else if (event.GetEvent() = m.stateMachine.POOL_EVENT_FILE_FAILED) then
        m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_FILE_DOWNLOAD_FAILURE, event.GetName() + chr(9) + event.GetFailureReason())
        m.bsp.diagnostics.PrintDebug("### File failed " + event.GetName() + ": " + event.GetFailureReason())
	else if (event.GetEvent() = m.stateMachine.POOL_EVENT_ALL_FAILED) then
        m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_SYNCSPEC_DOWNLOAD_FAILURE, event.GetFailureReason())		
        m.bsp.diagnostics.PrintDebug("### Sync failed: " + event.GetFailureReason())
		m.stateMachine.waitForStorageDetachedMsg$ = "Update failure (file failure). Remove the drive and the system will reboot."
        return m.stateMachine.stWaitForStorageDetached
	else if (event.GetEvent() = m.stateMachine.POOL_EVENT_ALL_DOWNLOADED) then
        m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_DOWNLOAD_COMPLETE, "")		
        m.bsp.diagnostics.PrintDebug("### All files downloaded")

		oldSyncSpecScriptsOnly  = m.stateMachine.currentSync.FilterFiles("download", { group: "script" } )
		newSyncSpecScriptsOnly  = m.stateMachine.newSync.FilterFiles("download", { group: "script" } )

		rebootRequired = false

		if not oldSyncSpecScriptsOnly.FilesEqualTo(newSyncSpecScriptsOnly) then

			' Protect all the media files that the current sync spec is using in case we fail part way through and need to continue using it. 
			if not (m.syncPool.ProtectFiles(m.stateMachine.currentSync, 0) and m.syncPool.ProtectFiles(m.stateMachine.newSync, 0)) then
				m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_SYNCPOOL_PROTECT_FAILURE, m.syncPool.GetFailureReason())
				m.bsp.diagnostics.PrintDebug("### ProtectFiles failed: " + m.syncPool.GetFailureReason())
				m.stateMachine.waitForStorageDetachedMsg$ = "Update failure (ProtectFiles). Remove the drive and the system will reboot."
				return m.stateMachine.stWaitForStorageDetached
			endif   

			event = m.syncPool.Realize(newSyncSpecScriptsOnly, "/")

			if event.GetEvent() <> m.stateMachine.EVENT_REALIZE_SUCCESS then
		        m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_REALIZE_FAILURE, stri(event.GetEvent()) + chr(9) + event.GetName() + chr(9) + event.GetFailureReason())
				m.bsp.diagnostics.PrintDebug("### Realize failed " + stri(event.GetEvent()) + chr(9) + event.GetName() + chr(9) + event.GetFailureReason() )
				m.stateMachine.waitForStorageDetachedMsg$ = "Update failure (Realize). Remove the drive and the system will reboot."
				return m.stateMachine.stWaitForStorageDetached
			endif

		endif

' Save to current-sync.xml then do cleanup
	    if not m.stateMachine.newSync.WriteToFile("local-sync.xml") then stop

        m.bsp.diagnostics.PrintTimestamp()
        m.bsp.diagnostics.PrintDebug("### USB UPDATE FILE DOWNLOAD COMPLETE")

		m.stateMachine.waitForStorageDetachedMsg$ = "Content update complete. Remove the drive and the system will reboot."
        return m.stateMachine.stWaitForStorageDetached

	endif

	return invalid

End Function


Function STWaitForStorageDetachedEventHandler(event As Object, stateData As Object) As Object

    stateData.nextState = invalid
    
    if type(event) = "roAssociativeArray" then      ' internal message event

        if IsString(event["EventType"]) then
        
            if event["EventType"] = "ENTRY_SIGNAL" then
            
                m.bsp.diagnostics.PrintDebug(m.id$ + ": entry signal")

' check to see if the drive is still in the device
				du = CreateObject("roStorageInfo", m.stateMachine.storagePath$)
				if type(du) = "roStorageInfo" then
					m.stateMachine.DisplayUSBUpdateStatus(m.stateMachine.waitForStorageDetachedMsg$)
				else
					m.stateMachine.DisplayUSBUpdateStatus("The drive was removed before the update was complete - the system will reboot shortly.")
					sleep(5000)
					RebootSystem()
				endif

                return "HANDLED"

            else if event["EventType"] = "EXIT_SIGNAL" then

                m.bsp.diagnostics.PrintDebug(m.id$ + ": exit signal")
            
            else if event["EventType"] = "PREPARE_FOR_RESTART" or event["EventType"] = "SWITCH_PRESENTATION" or event["EventType"] = "CONTENT_UPDATED" then ' consume these events during USB updates

				return "HANDLED"

			endif
			            
        endif
        
    else if type(event) = "roTimerEvent" or type(event) = "roUrlEvent" then	' consume these events during USB updates

		return "HANDLED"

	else if type(event) = "roStorageDetached" then

		m.stateMachine.logging.FlushLogFile()
	    RebootSystem()

	endif
	            
    stateData.nextState = m.superState
    return "SUPER"
    
End Function


Function CheckForUSBUpdate(storagePath$ As String) As Object

	syncSpecFilePath$ = storagePath$ + "/update/local-sync.xml"
	syncSpecFile = CreateObject("roReadFile", syncSpecFilePath$)
	if type(syncSpecFile) = "roReadFile" then
		return true
	endif

	return false

End Function


Sub DisplayUSBUpdateStatus(status$ As String)

	m.usbUpdateTW.Clear()
	m.usbUpdateTW.PushString(status$)
	m.usbUpdateTW.Show()

End Sub


Sub UpdateTimeClockEvents(updatedUserVariables As Object)

' m.bsp.logging.WriteDiagnosticLogEntry(m.bsp.diagnosticCodes.EVENT_LIVE_TEXT_FEED_DOWNLOAD_FAILURE, url$ + chr(9) + stri(event.GetResponseCode()) + chr(9) + event.GetFailureReason())

	if type(m.bsp.sign) = "roAssociativeArray" then
		sign = m.bsp.sign
		if type(sign.zonesHSM) = "roArray" then
			for each zoneHSM in sign.zonesHSM
				if type(zoneHSM.activeState) = "roAssociativeArray" then
					activeState = zoneHSM.activeState
					if type(activeState.timeClockEvents) = "roArray" then
						for each timeClockEvent in activeState.timeClockEvents
							if type(timeClockEvent.userVariable) = "roAssociativeArray" then
								updatedUserVariable = updatedUserVariables.Lookup(timeClockEvent.userVariableName$)
								if type(updatedUserVariable) = "roAssociativeArray" then
									dateTime$ = updatedUserVariable.GetCurrentValue()
									dateTime = FixDateTime(dateTime$)
									if type(dateTime) = "roDateTime" then
										' if timer is in the future, set it.
										if IsTimeoutInFuture(dateTime)
											setTimer = true
									        m.bsp.diagnostics.PrintDebug("Set timeout to " + dateTime.GetString())
										else
											setTimer = false
										endif

										if type(timeClockEvent.timer) = "roTimer" then
											timeClockEvent.timer.Stop()
										else if setTimer then
											timeClockEvent.timer = CreateObject("roTimer")
										endif

										if setTimer then
											timeClockEvent.timer.SetDateTime(dateTime)
											timeClockEvent.timer.SetPort(zoneHSM.msgPort)
											timeClockEvent.timer.Start()
										endif
									else
								        m.bsp.diagnostics.PrintDebug("Timeout specification " + dateTime$ + " is invalid")
										m.bsp.logging.WriteDiagnosticLogEntry(m.bsp.diagnosticCodes.EVENT_INVALID_DATE_TIME_SPEC, dateTime$)
									endif
								endif
							endif
						next
					endif
				endif
			next
		endif
	endif

End Sub

Function GenerateNonce(systemTime As Object) As String

	' Nonce just needs to be a reasonably unique alphanumeric string
	bytes = CreateObject("roByteArray")
	bytes.FromAsciiString(systemTime.GetUtcDateTime().GetString())
	nonce = bytes.ToBase64String()
	' Remove non word chars - just replace with arbitrary character
	rx = CreateObject("roRegEx","\W","")
	return rx.ReplaceAll(nonce,"z")

End Function

Function GenerateTimestamp(systemTime As Object) As String

	return systemTime.GetUtcDateTime().ToSecondsSinceEpoch().ToStr()
	
End Function

Function GenerateOAuthSignature(urlTransfer As Object, authenticationData As Object, nonce As String, timestamp As String) As String

	url$ = urlTransfer.GetUrl()
	' Generate sorted array of all parameters (header and query string)
	paramArray = CreateObject("roArray", 8, TRUE)
	' First, get parameters from URL query string
	queryIndex = instr(1, url$, "?")
	if queryIndex > 0 then
		params = mid(url$, queryIndex+1).tokenize("&")
		for each param in params
			nameval = param.tokenize("=")
			if nameval.Count() > 1 then
				paramItem = CreateObject("roAssociativeArray")
				paramItem.name = nameVal[0]
				paramItem.value = nameVal[1]
				paramArray.push(paramItem)
			endif
		next
	endif
	' Next, add the oauth parameters
	paramArray.push( { name: "oauth_consumer_key", value: authenticationData.ConsumerKey } )
	paramArray.push( { name: "oauth_nonce", value: urlTransfer.Escape(nonce) } )
	paramArray.push( { name: "oauth_signature_method", value: "HMAC-SHA1" } )
	paramArray.push( { name: "oauth_timestamp", value: timestamp } )
	paramArray.push( { name: "oauth_token", value: urlTransfer.Escape(authenticationData.AuthToken) } )
	paramArray.push( { name: "oauth_version", value: "1.0" } )
	
	' Now sort the parameter array
	max = paramArray.Count()
	sortedParamArray = CreateObject("roArray", max, FALSE)
	while (paramArray.Count() > 0)
		index = 0
		for i = 1 to paramArray.Count()-1
			if paramArray[i].name < paramArray[index].name then
				index = i
			endif
		end for
		sortedParamArray.push(paramArray[index])
		paramArray.Delete(index)
	end while
	
	' normalized parameter string
	normParams$ = ""
	for i = 0 to sortedParamArray.Count()-1
		normParams$ = normParams$ + urlTransfer.Escape(sortedParamArray[i].name) + "=" + urlTransfer.Escape(sortedParamArray[i].value)
		if i < sortedParamArray.Count()-1 then
			normParams$ = normParams$ + "&"
		endif
	end for
	
	' create signature base string
	if authenticationData.DoesExist("HttpMethod") and type(authenticationData.HttpMethod) = "roString" then
		sigBase$ = authenticationData.HttpMethod + "&"
	else
		sigBase$ = "GET&"
	endif
	
	if (queryIndex > 0)
		normUrl$ = left(url$,queryIndex-1)
	else
		normUrl$ = url$
	endif
	sigBase$ = sigBase$ + urlTransfer.Escape(normUrl$) + "&" + urlTransfer.Escape(normParams$) 
	
	'print "OAuth base string: " + sigBase$
	
	hashGen = CreateObject("roHashGenerator", "SHA1")
	hashGen.SetObfuscatedHmacKey(authenticationData.EncryptedTwitterSecrets)
	' get hash - we will NOT escape this here - that will be done when we generate the header
	hashStr$ = hashGen.hash(sigBase$).ToBase64String()
	
	return hashStr$

End Function

Function GetOAuthAuthorizationHeader(urlTransfer As Object, authenticationData As Object) As String

	systemTime = CreateObject("roSystemTime")    
	nonce = GenerateNonce(systemTime)
	timestamp = GenerateTimestamp(systemTime)

	s = "OAuth "
	s = s + "oauth_consumer_key=" + chr(34) + urlTransfer.Escape(authenticationData.ConsumerKey) + chr(34) + ","
	s = s + "oauth_nonce=" + chr(34) + nonce + chr(34) + ","
	s = s + "oauth_signature=" + chr(34) + urlTransfer.Escape(GenerateOAuthSignature(urlTransfer, authenticationData, nonce, timestamp)) + chr(34) + ","
	s = s + "oauth_signature_method=" + chr(34) + "HMAC-SHA1" + chr(34) + ","
	s = s + "oauth_timestamp=" + chr(34) + timestamp + chr(34) + ","
	s = s + "oauth_token=" + chr(34) + urlTransfer.Escape(authenticationData.AuthToken) + chr(34) + ","
	s = s + "oauth_version=" + chr(34) + "1.0" + chr(34)
	
	'print "Auth header: " + s

	return s

End Function

Sub RetrieveLiveDataFeed(liveDataFeed As Object)

	url$ = liveDataFeed.url.GetCurrentParameterValue()
	auth = liveDataFeed.authenticationData

    m.bsp.diagnostics.PrintDebug("### Retrieve live text data feed from " + url$)    
    m.bsp.logging.WriteDiagnosticLogEntry(m.bsp.diagnosticCodes.EVENT_RETRIEVE_LIVE_TEXT_FEED, url$)

	liveDataFeed.rssURLXfer = CreateObject("roUrlTransfer")
	liveDataFeed.rssURLXfer.SetUrl(url$)
	liveDataFeed.rssURLXfer.SetPort(m.bsp.msgPort)
	liveDataFeed.rssFileName$ = m.bsp.GetRSSTempFilename()
	liveDataFeed.rssURLXfer.SetTimeout(55000) ' 55 second timeout

	' Set authorization header, if authentication data is present
	if type(auth) = "roAssociativeArray" and type(auth.AuthType) = "roString" then
		if auth.AuthType = "OAuth 1.0a" then
			' Set OAuth header
			if not liveDataFeed.rssURLXfer.AddHeader("Authorization", GetOAuthAuthorizationHeader(liveDataFeed.rssURLXfer, auth)) then
				m.bsp.diagnostics.PrintDebug("Failed to set authorization header, reason: " + liveDataFeed.rssURLXfer.GetFailureReason())
			endif
		endif
	endif

	binding% = GetBinding(m.bsp.textFeedsXfersEnabledWired, m.bsp.textFeedsXfersEnabledWireless)
    m.bsp.diagnostics.PrintDebug("### Binding for RetrieveLiveDataFeed is " + stri(binding%))
	ok = liveDataFeed.rssURLXfer.BindToInterface(binding%)
	if not ok then stop

	liveDataFeed.rssURLXfer.AsyncGetToFile(liveDataFeed.rssFileName$)
	m.liveDataFeeds.AddReplace(stri(liveDataFeed.rssURLXfer.GetIdentity()), liveDataFeed)

End Sub


Function GetRSSDownloadInterval(rssDownloadSpec As Object) As Integer

	rssDownloadPeriodicValue% = 86400

    if type(rssDownloadSpec) = "roXMLList" then
    
        if rssDownloadSpec.Count() > 0 then
        
            rssDownloadSpecAttrs = rssDownloadSpec.GetAttributes()
            rssDownloadSpecType = rssDownloadSpecAttrs["type"]
        
            if rssDownloadSpecType = "periodic" then
                rssDownloadPeriodicValue% = val(rssDownloadSpecAttrs["value"])
            endif
        endif
    endif

	return rssDownloadPeriodicValue%

End Function

'endregion

'region Networking State Machine
' *************************************************
'
' Networking State Machine
'
' *************************************************
Function newNetworkingStateMachine(bsp As Object, msgPort As Object) As Object

    NetworkingStateMachine = newHSM()
    NetworkingStateMachine.InitialPseudostateHandler = InitializeNetworkingStateMachine

	NetworkingStateMachine.bsp = bsp
	NetworkingStateMachine.msgPort = msgPort
	NetworkingStateMachine.systemTime = bsp.systemTime
	NetworkingStateMachine.diagnostics = bsp.diagnostics
	NetworkingStateMachine.logging = bsp.logging

    NetworkingStateMachine.RestartContentDownloadWindowStartTimer = RestartContentDownloadWindowStartTimer
    NetworkingStateMachine.RestartContentDownloadWindowEndTimer = RestartContentDownloadWindowEndTimer
    NetworkingStateMachine.RestartHeartbeatsWindowStartTimer = RestartHeartbeatsWindowStartTimer
    NetworkingStateMachine.RestartHeartbeatsWindowEndTimer = RestartHeartbeatsWindowEndTimer
	NetworkingStateMachine.RestartWindowStartTimer = RestartWindowStartTimer
	NetworkingStateMachine.RestartWindowEndTimer = RestartWindowEndTimer

    NetworkingStateMachine.SetSystemInfo = SetSystemInfo
    NetworkingStateMachine.AddMiscellaneousHeaders = AddMiscellaneousHeaders
	
    NetworkingStateMachine.DeviceDownloadItems = CreateObject("roArray", 8, true)
    NetworkingStateMachine.DeviceDownloadItemsPendingUpload = CreateObject("roArray", 8, true)
    NetworkingStateMachine.AddDeviceDownloadItem = AddDeviceDownloadItem
    NetworkingStateMachine.UploadDeviceDownload = UploadDeviceDownload

	NetworkingStateMachine.FileListPendingUpload = true
    NetworkingStateMachine.DeviceDownloadProgressItems = CreateObject("roAssociativeArray")
    NetworkingStateMachine.DeviceDownloadProgressItemsPendingUpload = CreateObject("roAssociativeArray")
	NetworkingStateMachine.PushDeviceDownloadProgressItem = PushDeviceDownloadProgressItem
    NetworkingStateMachine.AddDeviceDownloadProgressItem = AddDeviceDownloadProgressItem
    NetworkingStateMachine.UploadDeviceDownloadProgressItems = UploadDeviceDownloadProgressItems
    NetworkingStateMachine.UploadDeviceDownloadProgressFileList = UploadDeviceDownloadProgressFileList
	NetworkingStateMachine.BuildFileDownloadList = BuildFileDownloadList
    
	NetworkingStateMachine.SendTrafficUpload = SendTrafficUpload
    NetworkingStateMachine.UploadTrafficDownload = UploadTrafficDownload
    NetworkingStateMachine.UploadMRSSTrafficDownload = UploadMRSSTrafficDownload
	NetworkingStateMachine.pendingMRSSContentDownloaded# = 0
    NetworkingStateMachine.lastMRSSContentDownloaded# = 0
    
    NetworkingStateMachine.EventItems = CreateObject("roArray", 8, true)
    NetworkingStateMachine.AddEventItem = AddEventItem
    NetworkingStateMachine.UploadEvent = UploadEvent
        
    NetworkingStateMachine.DeviceErrorItems = CreateObject("roArray", 8, true)
    NetworkingStateMachine.AddDeviceErrorItem = AddDeviceErrorItem
    NetworkingStateMachine.UploadDeviceError = UploadDeviceError
    
    NetworkingStateMachine.BatteryChargerItems = CreateObject("roArray", 8, true)
    NetworkingStateMachine.AddBatteryChargerItem = AddBatteryChargerItem
    NetworkingStateMachine.UploadBatteryCharger = UploadBatteryCharger
    
    NetworkingStateMachine.deviceDownloadProgressUploadURL = invalid
    NetworkingStateMachine.deviceDownloadUploadURL = invalid
    NetworkingStateMachine.trafficDownloadUploadURL = invalid
    NetworkingStateMachine.mrssTrafficDownloadUploadURL = invalid
    NetworkingStateMachine.eventUploadURL = invalid
    NetworkingStateMachine.deviceErrorUploadURL = invalid
    NetworkingStateMachine.batteryChargerUploadURL = invalid

	NetworkingStateMachine.LogProtectFilesFailure = LogProtectFilesFailure

' logging
    NetworkingStateMachine.UploadLogFiles = UploadLogFiles
    NetworkingStateMachine.UploadLogFileHandler = UploadLogFileHandler
    NetworkingStateMachine.uploadLogFileURLXfer = invalid
    NetworkingStateMachine.uploadLogFileURL$ = ""
    NetworkingStateMachine.uploadLogFolder = "logs"
    NetworkingStateMachine.uploadLogArchiveFolder = "archivedLogs"
    NetworkingStateMachine.uploadLogFailedFolder = "failedLogs"
    NetworkingStateMachine.enableLogDeletion = true
    
    NetworkingStateMachine.SendHeartbeat = SendHeartbeat

    NetworkingStateMachine.AddUploadHeaders = AddUploadHeaders

    NetworkingStateMachine.RebootAfterEventsSent = RebootAfterEventsSent
    NetworkingStateMachine.WaitForTransfersToComplete = WaitForTransfersToComplete

    NetworkingStateMachine.ResetDownloadTimerToDoRetry = ResetDownloadTimerToDoRetry
    NetworkingStateMachine.retryInterval% = 60
    NetworkingStateMachine.numRetries% = 0
    NetworkingStateMachine.maxRetries% = 3

    NetworkingStateMachine.ResetHeartbeatTimerToDoRetry = ResetHeartbeatTimerToDoRetry
    NetworkingStateMachine.heartbeatRetryInterval% = 60
    NetworkingStateMachine.numHeartbeatRetries% = 0
    NetworkingStateMachine.maxHeartbeatRetries% = 3

	NetworkingStateMachine.fileDownloadFailureCount% = 0
	NetworkingStateMachine.maxFileDownloadFailures% = 3

    NetworkingStateMachine.POOL_EVENT_FILE_DOWNLOADED = 1
    NetworkingStateMachine.POOL_EVENT_FILE_FAILED = -1
    NetworkingStateMachine.POOL_EVENT_ALL_DOWNLOADED = 2
    NetworkingStateMachine.POOL_EVENT_ALL_FAILED = -2

    NetworkingStateMachine.SYNC_ERROR_CANCELLED = -10001
    NetworkingStateMachine.SYNC_ERROR_CHECKSUM_MISMATCH = -10002
    NetworkingStateMachine.SYNC_ERROR_EXCEPTION = -10003
    NetworkingStateMachine.SYNC_ERROR_DISK_ERROR = -10004
    NetworkingStateMachine.SYNC_ERROR_POOL_UNSATISFIED = -10005
    
    NetworkingStateMachine.EVENT_REALIZE_SUCCESS = 101

    NetworkingStateMachine.stTop = NetworkingStateMachine.newHState(bsp, "Top")
    NetworkingStateMachine.stTop.HStateEventHandler = STTopEventHandler
    
    NetworkingStateMachine.stNetworkScheduler = NetworkingStateMachine.newHState(bsp, "NetworkScheduler")
    NetworkingStateMachine.stNetworkScheduler.HStateEventHandler = STNetworkSchedulerEventHandler
	NetworkingStateMachine.stNetworkScheduler.superState = NetworkingStateMachine.stTop

    NetworkingStateMachine.stWaitForTimeout = NetworkingStateMachine.newHState(bsp, "WaitForTimeout")
    NetworkingStateMachine.stWaitForTimeout.HStateEventHandler = STWaitForTimeoutEventHandler
	NetworkingStateMachine.stWaitForTimeout.superState = NetworkingStateMachine.stNetworkScheduler

    NetworkingStateMachine.stRetrievingSyncList = NetworkingStateMachine.newHState(bsp, "RetrievingSyncList")
    NetworkingStateMachine.stRetrievingSyncList.StartSync = StartSync 
    NetworkingStateMachine.stRetrievingSyncList.SyncSpecXferEvent = SyncSpecXferEvent 
    NetworkingStateMachine.stRetrievingSyncList.HStateEventHandler = STRetrievingSyncListEventHandler
	NetworkingStateMachine.stRetrievingSyncList.superState = NetworkingStateMachine.stNetworkScheduler
	NetworkingStateMachine.stRetrievingSyncList.ConfigureNetwork = ConfigureNetwork
	NetworkingStateMachine.stRetrievingSyncList.UpdateRegistrySetting = UpdateRegistrySetting

    NetworkingStateMachine.stDownloadingSyncFiles = NetworkingStateMachine.newHState(bsp, "DownloadingSyncFiles")
    NetworkingStateMachine.stDownloadingSyncFiles.StartSyncListDownload = StartSyncListDownload
    NetworkingStateMachine.stDownloadingSyncFiles.HandleSyncPoolEvent = HandleSyncPoolEvent
    NetworkingStateMachine.stDownloadingSyncFiles.HStateEventHandler = STDownloadingSyncFilesEventHandler
	NetworkingStateMachine.stDownloadingSyncFiles.superState = NetworkingStateMachine.stNetworkScheduler

	NetworkingStateMachine.topState = NetworkingStateMachine.stTop
	
	return NetworkingStateMachine
	
End Function


Function InitializeNetworkingStateMachine() As Object

    ' determine whether or not to enable proxy mode support
	m.proxy_mode = false
	
    ' if caching is enabled, set parameter indicating whether downloads are only allowed from the cache
    m.downloadOnlyIfCached = false   
    
    ' combination of proxies and wireless not yet supported
    nc = CreateObject("roNetworkConfiguration", 0)
    if type(nc) = "roNetworkConfiguration" then
        if nc.GetProxy() <> "" then
	        m.proxy_mode = true
            OnlyDownloadIfCached$ = m.bsp.registrySettings.OnlyDownloadIfCached$
            if OnlyDownloadIfCached$ = "true" then m.downloadOnlyIfCached = true
        endif
    endif
    nc = invalid

    ' Load up the current sync specification so we have it ready
	m.currentSync = CreateObject("roSyncSpec")
	if type(m.currentSync) <> "roSyncSpec" then return false
	if not m.currentSync.ReadFromFile("current-sync.xml") then
	    m.diagnostics.PrintDebug("### No current sync state available")
	    return false
	endif

    m.accountName$ = m.currentSync.LookupMetadata("server", "account")

    base$ = m.currentSync.LookupMetadata("client", "base")
    nextURL = GetURL(base$, m.currentSync.LookupMetadata("client", "next"))
	m.eventURL = GetURL(base$, m.currentSync.LookupMetadata("client", "event"))
    m.deviceDownloadProgressURL = GetURL(base$, m.currentSync.LookupMetadata("client", "devicedownloadprogress"))
	m.deviceDownloadURL = GetURL(base$, m.currentSync.LookupMetadata("client", "devicedownload"))
	m.trafficDownloadURL = GetURL(base$, m.currentSync.LookupMetadata("client", "trafficdownload"))
	m.deviceErrorURL = GetURL(base$, m.currentSync.LookupMetadata("client", "deviceerror"))
    m.uploadLogFileURL$ = GetURL(base$, m.currentSync.LookupMetadata("client", "uploadlogs"))
    m.batteryChargerURL$ = GetURL(base$, m.currentSync.LookupMetadata("client", "batteryCharger"))
	m.heartbeatURL$ = GetURL(base$,  m.currentSync.LookupMetadata("client", "heartbeat"))

	timezone = m.currentSync.LookupMetadata("client", "timezone")
    if timezone <> "" then
        m.systemTime.SetTimeZone(timezone)
    endif

    m.diagnostics.PrintTimestamp()
    m.diagnostics.PrintDebug("### Current active sync list suggests next URL of " + nextURL)
    
	if nextURL = "" then stop
    if m.eventURL = "" then stop
    
    m.user$ = m.currentSync.LookupMetadata("server", "user")
    m.password$ = m.currentSync.LookupMetadata("server", "password")
    if m.user$ <> "" or m.password$ <> "" then
        m.setUserAndPassword = true
		enableUnsafeAuthentication$ = m.currentSync.LookupMetadata("server", "enableUnsafeAuthentication")
		if lcase(enableUnsafeAuthentication$) = "true" then
			m.enableUnsafeAuthentication = true
		else
			m.enableUnsafeAuthentication = false
		endif
    else
        m.setUserAndPassword = false
		m.enableUnsafeAuthentication = false
    endif

    useWireless$ = m.currentSync.LookupMetadata("client", "useWireless")
    if not m.modelSupportsWifi then useWireless$ = "no"

	if useWireless$ = "yes" then
		m.useWireless = true
	else
		m.useWireless = false
	endif
	        
' get net connect parameters, setup timer, and rate limits
    timeBetweenNetConnects$ = m.currentSync.LookupMetadata("client", "timeBetweenNetConnects")
    contentDownloadsRestricted = m.currentSync.LookupMetadata("client", "contentDownloadsRestricted")
    contentDownloadRangeStart = m.currentSync.LookupMetadata("client", "contentDownloadRangeStart")
    contentDownloadRangeLength = m.currentSync.LookupMetadata("client", "contentDownloadRangeLength")

    timeBetweenHeartbeats$ = m.currentSync.LookupMetadata("client", "timeBetweenHeartbeats")
    heartbeatsRestricted = m.currentSync.LookupMetadata("client", "heartbeatsRestricted")
    heartbeatsRangeStart = m.currentSync.LookupMetadata("client", "heartbeatsRangeStart")
    heartbeatsRangeLength = m.currentSync.LookupMetadata("client", "heartbeatsRangeLength")

	m.wiredRateLimits = {}
	if m.useWireless then
		rateLimitModeOutsideWindowWired$ = m.currentSync.LookupMetadata("client", "rateLimitModeOutsideWindow_2")
		rateLimitRateOutsideWindowWired$ = m.currentSync.LookupMetadata("client", "rateLimitRateOutsideWindow_2")
		rateLimitModeInWindowWired$ = m.currentSync.LookupMetadata("client", "rateLimitModeInWindow_2")
		rateLimitRateInWindowWired$ = m.currentSync.LookupMetadata("client", "rateLimitRateInWindow_2")
	else
		rateLimitModeOutsideWindowWired$ = m.currentSync.LookupMetadata("client", "rateLimitModeOutsideWindow")
		rateLimitRateOutsideWindowWired$ = m.currentSync.LookupMetadata("client", "rateLimitRateOutsideWindow")
		rateLimitModeInWindowWired$ = m.currentSync.LookupMetadata("client", "rateLimitModeInWindow")
		rateLimitRateInWindowWired$ = m.currentSync.LookupMetadata("client", "rateLimitRateInWindow")
	endif
	SetRateLimitValues(true, m.wiredRateLimits, rateLimitModeOutsideWindowWired$, rateLimitRateOutsideWindowWired$, rateLimitModeInWindowWired$, rateLimitRateInWindowWired$)

	m.wirelessRateLimits = {}
	if m.useWireless then
		rateLimitModeOutsideWindowWireless$ = m.currentSync.LookupMetadata("client", "rateLimitModeOutsideWindow")
		rateLimitRateOutsideWindowWireless$ = m.currentSync.LookupMetadata("client", "rateLimitRateOutsideWindow")
		rateLimitModeInWindowWireless$ = m.currentSync.LookupMetadata("client", "rateLimitModeInWindow")
		rateLimitRateInWindowWireless$ = m.currentSync.LookupMetadata("client", "rateLimitRateInWindow")
	else
		rateLimitModeOutsideWindowWireless$ = m.currentSync.LookupMetadata("client", "rateLimitModeOutsideWindow_2")
		rateLimitRateOutsideWindowWireless$ = m.currentSync.LookupMetadata("client", "rateLimitRateOutsideWindow_2")
		rateLimitModeInWindowWireless$ = m.currentSync.LookupMetadata("client", "rateLimitModeInWindow_2")
		rateLimitRateInWindowWireless$ = m.currentSync.LookupMetadata("client", "rateLimitRateInWindow_2")
	endif
	SetRateLimitValues(true, m.wirelessRateLimits, rateLimitModeOutsideWindowWireless$, rateLimitRateOutsideWindowWireless$, rateLimitModeInWindowWireless$, rateLimitRateInWindowWireless$)

' if the values above are not found, try to retrieve them from the registry. for simple networking (pre BA 2.3), only the
' initial sync spec will include these values
    if timeBetweenNetConnects$ = "" then
		timeBetweenNetConnects$ = m.bsp.registrySettings.timeBetweenNetConnects$
        if timeBetweenNetConnects$ = "" then print "Error: timeBetweenNetConnects not found in either the sync spec or the registry":stop
        contentDownloadsRestricted = m.bsp.registrySettings.contentDownloadsRestricted
        if contentDownloadsRestricted = "" then print "Error: contentDownloadsRestricted not set in registry":stop
        contentDownloadRangeStart = m.bsp.registrySettings.contentDownloadRangeStart
        contentDownloadRangeLength = m.bsp.registrySettings.contentDownloadRangeLength
    endif

' check for timeBetweenNetConnects override
	tbnco$ = m.bsp.registrySettings.tbnco$
	if tbnco$ <> "" then
		timeBetweenNetConnects$	= tbnco$
	endif    
    
    m.timeBetweenNetConnects% = val(timeBetweenNetConnects$)
    m.diagnostics.PrintDebug("### Time between net connects = " + timeBetweenNetConnects$)
    m.currentTimeBetweenNetConnects% = m.timeBetweenNetConnects%
    m.networkTimerDownload = CreateObject("roAssociativeArray")
    m.networkTimerDownload.timerType = "TIMERTYPEPERIODIC"
    m.networkTimerDownload.timerInterval = m.timeBetweenNetConnects%
    
	if timeBetweenHeartbeats$ = "" then
		m.timeBetweenHearbeats% = 0
	else
	    m.timeBetweenHearbeats% = val(timeBetweenHeartbeats$)
    endif
    m.currentTimeBetweenHeartbeats% = m.timeBetweenHearbeats%
	m.diagnostics.PrintDebug("### Time between heartbeats = " + timeBetweenHeartbeats$)

    newTimer = CreateObject("roTimer")
    newTimer.SetPort(m.msgPort)
    
    m.networkTimerDownload.timer = newTimer

' get time range for when net connects can occur
    if contentDownloadsRestricted = "yes" then
        m.contentDownloadsRestricted = true
        m.contentDownloadRangeStart% = val(contentDownloadRangeStart)
        m.contentDownloadRangeLength% = val(contentDownloadRangeLength)
        m.diagnostics.PrintDebug("### Content downloads are restricted to the time from " + contentDownloadRangeStart + " for " + contentDownloadRangeLength + " minutes.")
    else
        m.diagnostics.PrintDebug("### Content downloads are unrestricted")
        m.contentDownloadsRestricted = false
    endif

' get time range for when heartbeats can occur
    if heartbeatsRestricted = "yes" then
        m.heartbeatsRestricted = true
        m.heartbeatsRangeStart% = val(heartbeatsRangeStart)
        m.heartbeatsRangeLength% = val(heartbeatsRangeLength)
        m.diagnostics.PrintDebug("### Heartbeats are restricted to the time from " + heartbeatsRangeStart + " for " + heartbeatsRangeLength + " minutes.")
    else
        m.diagnostics.PrintDebug("### Heartbeats are unrestricted")
        m.heartbeatsRestricted = false
    endif

' program the rate limit for networking
    if m.contentDownloadsRestricted then
        currentTime = m.systemTime.GetLocalDateTime()
        startOfRange% = m.contentDownloadRangeStart%
        endOfRange% = startOfRange% + m.contentDownloadRangeLength%
        
        notInDownloadWindow = OutOfDownloadWindow(currentTime, startOfRange%, endOfRange%)
        
		if notInDownloadWindow then
			wiredRL% = m.wiredRateLimits.rlOutsideWindow%
			wirelessRL% = m.wirelessRateLimits.rlOutsideWindow%
		else
			wiredRL% = m.wiredRateLimits.rlInWindow%
			wirelessRL% = m.wirelessRateLimits.rlInWindow%
		endif
    else
		wiredRL% = m.wiredRateLimits.rlOutsideWindow%
		wirelessRL% = m.wirelessRateLimits.rlOutsideWindow%
	endif

' diagnostic web server
	dwsParams = GetDWSParams(m.currentSync, m.bsp.registrySettings)
	
	dwsAA = CreateObject("roAssociativeArray")
	if dwsParams.dwsEnabled$ = "yes" then
		dwsAA["port"] = "80"
		dwsAA["password"] = dwsParams.dwsPassword$
	endif

	SetDownloadRateLimit(m.diagnostics, 0, wiredRL%)

	if m.useWireless then
		SetDownloadRateLimit(m.diagnostics, 1, wirelessRL%)
	endif
                
    nc = CreateObject("roNetworkConfiguration", 0)
    if type(nc) = "roNetworkConfiguration"
		dwsRebootRequired = nc.SetupDWS(dwsAA)
		if dwsRebootRequired then RebootSystem()
	endif

    return m.stRetrievingSyncList
	
End Function


Function GetDwsParams(syncSpec As Object, registrySettings As Object)

	dwsEnabled$ = syncSpec.LookupMetadata("client", "dwsEnabled")
	
	if dwsEnabled$ = "" then
		' simple file networking case
		dwsEnabled$ = registrySettings.dwsEnabled$
		dwsPassword$ = registrySettings.dwsPassword$
	else
		dwsPassword$ = syncSpec.LookupMetadata("client", "dwsPassword")
	endif
	
	dwsParams = CreateObject("roAssociativeArray")
	dwsParams.dwsEnabled$ = dwsEnabled$
	dwsParams.dwsPassword$ = dwsPassword$
	
	return dwsParams
	
End Function


Function OutOfDownloadWindow(currentTime As Object, startOfRangeInMinutes% As Integer, endOfRangeInMinutes% As Integer)

	secondsPerDay% = 24 * 60 * 60
	
	secondsSinceMidnight% = currentTime.GetHour() * 3600 + currentTime.GetMinute() * 60 + currentTime.GetSecond()
	startOfRangeInSeconds% = startOfRangeInMinutes% * 60
	endOfRangeInSeconds% = endOfRangeInMinutes% * 60
	
	notInDownloadWindow = false
	if endOfRangeInSeconds% <= secondsPerDay% then
		if not(secondsSinceMidnight% >= startOfRangeInSeconds% and secondsSinceMidnight% <= endOfRangeInSeconds%) then
			notInDownloadWindow = true
		endif
	else
		if not(((secondsSinceMidnight% >= startOfRangeInSeconds%) and (secondsSinceMidnight% < secondsPerDay%)) or (secondsSinceMidnight% < (endOfRangeInSeconds% - secondsPerDay%))) then
			notInDownloadWindow = true
		endif
	endif
	
	return notInDownloadWindow
	
End Function


Sub SetRateLimitValues(updateIfNotSpecified As boolean, rateLimits As Object, rateLimitModeOutsideWindow$ As String, rateLimitRateOutsideWindow$ As String, rateLimitModeInWindow$ As String, rateLimitRateInWindow$ As String)

	if rateLimitModeOutsideWindow$ = "unlimited" then
		rateLimits.rlOutsideWindow% = 0
	else if rateLimitModeOutsideWindow$ = "specified" then
		if rateLimitRateOutsideWindow$ <> "" then
			rateLimits.rlOutsideWindow% = int(val(rateLimitRateOutsideWindow$))
		endif
	else if updateIfNotSpecified or rateLimitModeOutsideWindow$ <> "" then
		rateLimits.rlOutsideWindow% = -1
	endif

	if rateLimitModeInWindow$ = "unlimited" then
		rateLimits.rlInWindow% = 0
	else if rateLimitModeInWindow$ = "specified" then
		if rateLimitRateInWindow$ <> "" then
			rateLimits.rlInWindow% = int(val(rateLimitRateInWindow$))
		endif
	else if updateIfNotSpecified or rateLimitModeInWindow$ <> "" then
		rateLimits.rlInWindow% = -1
	endif

End Sub


Function GetURL(base$ As String, urlFromSyncSpec$ As String) As String

    if instr(1, urlFromSyncSpec$, ":") > 0 then
        url$ = urlFromSyncSpec$
    else if urlFromSyncSpec$ = "" then
        url$ = ""
    else
        url$ = base$ + urlFromSyncSpec$
    endif
    
    return url$
    
End Function


Sub AddUploadHeaders(url As Object, contentDisposition$)

'    url.SetHeaders({})
    url.SetHeaders(m.currentSync.GetMetadata("server"))

' Add device unique identifier, timezone
    url.AddHeader("DeviceID", m.deviceUniqueID$)
    
    url.AddHeader("DeviceModel", m.deviceModel$)
    url.AddHeader("DeviceFamily", m.deviceFamily$)
    url.AddHeader("DeviceFWVersion", m.firmwareVersion$)
    url.AddHeader("DeviceSWVersion", m.autorunVersion$)
    url.AddHeader("CustomAutorunVersion", m.customAutorunVersion$)
    
    url.AddHeader("utcTime", m.systemTime.GetUtcDateTime().GetString())

    url.AddHeader("Content-Type", "application/octet-stream")
    
    url.AddHeader("Content-Disposition", contentDisposition$)

End Sub


Function GetContentDisposition(file As String) As String

'Content-Disposition: form-data; name="file"; filename="UploadPlaylog.xml"

    contentDisposition$ = "form-data; name="
    contentDisposition$ = contentDisposition$ + chr(34)
    contentDisposition$ = contentDisposition$ + "file"
    contentDisposition$ = contentDisposition$ + chr(34)
    contentDisposition$ = contentDisposition$ + "; filename="
    contentDisposition$ = contentDisposition$ + chr(34)
    contentDisposition$ = contentDisposition$ + file
    contentDisposition$ = contentDisposition$ + chr(34)

    return contentDisposition$
    
End Function


Sub BuildFileDownloadList(syncSpec As Object)

	listOfDownloadFiles = syncSpec.GetFileList("download")
        
    fileInPoolStatus = CreateObject("roAssociativeArray")
	tmpSyncPool = CreateObject("roSyncPool", "pool")
	if type(tmpSyncPool) = "roSyncPool" then
        fileInPoolStatus = tmpSyncPool.QueryFiles(syncSpec)
    endif
        
    m.filesToDownload = CreateObject("roAssociativeArray")
    m.chargeableFiles = CreateObject("roAssociativeArray")
                
    for each downloadFile in listOfDownloadFiles
        
        if not m.filesToDownload.DoesExist(downloadFile.hash) then
            fileToDownload = CreateObject("roAssociativeArray")
            fileToDownload.name = downloadFile.name
            fileToDownload.size = downloadFile.size
            fileToDownload.hash = downloadFile.hash
                
            fileToDownload.currentFilePercentage$ = ""
            fileToDownload.status$ = ""

            ' check to see if this file is already in the pool (and therefore doesn't need to be downloaded)
            if fileInPoolStatus.DoesExist(downloadFile.name) then
                fileInPool = fileInPoolStatus.Lookup(downloadFile.name)
                if fileInPool then
                    fileToDownload.currentFilePercentage$ = "100"
                    fileToDownload.status$ = "ok"
                endif
            endif
                
            m.filesToDownload.AddReplace(downloadFile.hash, fileToDownload)
        endif
            
        if IsString(downloadFile.chargeable) then
            if lcase(downloadFile.chargeable) = "yes" then
                m.chargeableFiles[downloadFile.name] = true
            endif
        endif
            
    next
                                
End Sub


Sub PushDeviceDownloadProgressItem(fileItem As Object, type$ As String, currentFilePercentage$ As String, status$ As String)

    deviceDownloadProgressItem = CreateObject("roAssociativeArray")
    deviceDownloadProgressItem.type$ = type$
    deviceDownloadProgressItem.name$ = fileItem.name
    deviceDownloadProgressItem.hash$ = fileItem.hash
    deviceDownloadProgressItem.size$ = fileItem.size
    deviceDownloadProgressItem.currentFilePercentage$ = currentFilePercentage$
    deviceDownloadProgressItem.status$ = status$
    deviceDownloadProgressItem.utcTime$ = m.systemTime.GetUtcDateTime().GetString()

	if m.DeviceDownloadProgressItems.DoesExist(fileItem.name)
		existingDeviceDownloadProgressItem = m.DeviceDownloadProgressItems.Lookup(fileItem.name)
		deviceDownloadProgressItem.type$ = existingDeviceDownloadProgressItem.type$
	endif

	m.DeviceDownloadProgressItems.AddReplace(fileItem.name, deviceDownloadProgressItem)

End Sub


Sub AddDeviceDownloadProgressItem(fileItem As Object, currentFilePercentage$ As String, status$ As String)

	m.PushDeviceDownloadProgressItem(fileItem, "deviceDownloadProgressItem", currentFilePercentage$, status$)
    m.UploadDeviceDownloadProgressItems()
    
End Sub


Sub UploadDeviceDownloadProgressItems()

    if m.deviceDownloadProgressURL = "" then
        m.diagnostics.PrintDebug("### UploadDeviceDownloadProgressItems - deviceDownloadProgressURL not set, return")
        return
    else
        m.diagnostics.PrintDebug("### UploadDeviceDownloadProgressItems")
    endif

' verify that there is content to upload
    if m.DeviceDownloadProgressItems.IsEmpty() and m.DeviceDownloadProgressItemsPendingUpload.IsEmpty() then return
    
' create roUrlTransfer if needed
	if type(m.deviceDownloadProgressUploadURL) <> "roUrlTransfer" then
		m.deviceDownloadProgressUploadURL = CreateObject("roUrlTransfer")
        m.deviceDownloadProgressUploadURL.SetUrl(m.deviceDownloadProgressURL)
        m.deviceDownloadProgressUploadURL.SetPort(m.msgPort)
		m.deviceDownloadProgressUploadURL.SetTimeout(900000)
	endif
	    
' if a transfer is in progress, return
	if not m.deviceDownloadProgressUploadURL.SetUrl(m.deviceDownloadProgressURL) then
        m.diagnostics.PrintDebug("### UploadDeviceDownloadProgressItems - upload already in progress")
		return 
	else
        m.diagnostics.PrintDebug("### UploadDeviceDownloadProgressItems - proceed with post")
	end if

' merge new items into pending items
	for each deviceDownloadProgressItemKey in m.DeviceDownloadProgressItems
		deviceDownloadProgressItem = m.DeviceDownloadProgressItems.Lookup(deviceDownloadProgressItemKey)
		if m.DeviceDownloadProgressItemsPendingUpload.DoesExist(deviceDownloadProgressItem.name$)
			existingDeviceDownloadProgressItem = m.DeviceDownloadProgressItemsPendingUpload.Lookup(deviceDownloadProgressItem.name$)
			deviceDownloadProgressItem.type$ = existingDeviceDownloadProgressItem.type$
		endif
		m.DeviceDownloadProgressItemsPendingUpload.AddReplace(deviceDownloadProgressItem.name$, deviceDownloadProgressItem)
	next

' generate the XML and upload the data
    root = CreateObject("roXMLElement")
    
    root.SetName("DeviceDownloadProgressItems")

	for each deviceDownloadProgressItemKey in m.DeviceDownloadProgressItemsPendingUpload
		deviceDownloadProgressItem = m.DeviceDownloadProgressItemsPendingUpload.Lookup(deviceDownloadProgressItemKey)
		BuildDeviceDownloadProgressItemXML(root, deviceDownloadProgressItem)
    next

    xml = root.GenXML({ indent: " ", newline: chr(10), header: true })

' prepare the upload    
    contentDisposition$ = GetContentDisposition("UploadDeviceDownloadProgressItems.xml")
    m.AddUploadHeaders(m.deviceDownloadProgressUploadURL, contentDisposition$)
    m.deviceDownloadProgressUploadURL.AddHeader("updateDeviceLastDownload", "true")

	binding% = GetBinding(m.bsp.contentXfersEnabledWired, m.bsp.contentXfersEnabledWireless)
    m.diagnostics.PrintDebug("### Binding for UploadDeviceDownloadProgressItems is " + stri(binding%))
	ok = m.deviceDownloadProgressUploadURL.BindToInterface(binding%)
	if not ok then stop

	ok = m.deviceDownloadProgressUploadURL.AsyncPostFromString(xml)
    if not ok then
        m.diagnostics.PrintDebug("### UploadDeviceDownloadProgressItems - AsyncPostFromString failed")
    endif
    
	m.DeviceDownloadProgressItems.Clear()

End Sub


Sub BuildDeviceDownloadProgressItemXML(root As Object, deviceDownloadProgressItem As Object)

    item = root.AddBodyElement()
    item.SetName(deviceDownloadProgressItem.type$)

    elem = item.AddElement("name")
    elem.SetBody(deviceDownloadProgressItem.name$)
    
    elem = item.AddElement("hash")
    elem.SetBody(deviceDownloadProgressItem.hash$)
    
    elem = item.AddElement("size")
    elem.SetBody(deviceDownloadProgressItem.size$)
    
    elem = item.AddElement("currentFilePercentage")
    elem.SetBody(deviceDownloadProgressItem.currentFilePercentage$)
    
    elem = item.AddElement("status")
    elem.SetBody(deviceDownloadProgressItem.status$)
        
    elem = item.AddElement("utcTime")
    elem.SetBody(deviceDownloadProgressItem.utcTime$)

End Sub


Sub UploadDeviceDownloadProgressFileList()

    if m.deviceDownloadProgressURL = "" then
        m.diagnostics.PrintDebug("### UploadDeviceDownloadProgressFileList - deviceDownloadProgressURL not set, return")
        return
    else
        m.diagnostics.PrintDebug("### UploadDeviceDownloadProgressFileList")
    endif

' create roUrlTransfer if needed
	if type(m.deviceDownloadProgressUploadURL) <> "roUrlTransfer" then
		m.deviceDownloadProgressUploadURL = CreateObject("roUrlTransfer")
        m.deviceDownloadProgressUploadURL.SetUrl(m.deviceDownloadProgressURL)
        m.deviceDownloadProgressUploadURL.SetPort(m.msgPort)
		m.deviceDownloadProgressUploadURL.SetTimeout(900000)
	else
' cancel any uploads of this type that are in progress
		m.deviceDownloadProgressUploadURL.AsyncCancel()
	endif


' this data will overwrite any pending data so clear the existing data structures
    m.DeviceDownloadProgressItems.Clear()
    m.DeviceDownloadProgressItemsPendingUpload.Clear()

' create progress items for each file in the sync spec
    for each fileToDownloadKey in m.filesToDownload
        fileToDownload = m.filesToDownload.Lookup(fileToDownloadKey)
		m.PushDeviceDownloadProgressItem(fileToDownload, "fileInSyncSpec", fileToDownload.currentFilePercentage$, fileToDownload.status$)
	next

	m.UploadDeviceDownloadProgressItems()

End Sub


Sub AddDeviceDownloadItem(downloadEvent$ As String, fileName$ As String, downloadData$ As String)
    
    ' Make sure the array doesn't get too big.
    while m.DeviceDownloadItems.Count() > 100
        m.DeviceDownloadItems.Shift()
    end while

    deviceDownloadItem = CreateObject("roAssociativeArray")
    deviceDownloadItem.downloadEvent$ = downloadEvent$
    deviceDownloadItem.fileName$ = fileName$
    deviceDownloadItem.downloadData$ = downloadData$
    m.DeviceDownloadItems.push(deviceDownloadItem)

    m.UploadDeviceDownload()
    
End Sub


Sub UploadDeviceDownload()

    if m.deviceDownloadURL = "" then
        m.diagnostics.PrintDebug("### UploadDeviceDownload - deviceDownloadURL not set, return")
        return
    else
        m.diagnostics.PrintDebug("### UploadDeviceDownload")
    endif

' verify that there is content to upload
    if m.DeviceDownloadItems.Count() = 0 and m.DeviceDownloadItemsPendingUpload.Count() = 0 then return

' create roUrlTransfer if needed
	if type(m.deviceDownloadUploadURL) <> "roUrlTransfer" then
		m.deviceDownloadUploadURL = CreateObject("roUrlTransfer")
        m.deviceDownloadUploadURL.SetUrl(m.deviceDownloadURL)
        m.deviceDownloadUploadURL.SetPort(m.msgPort)
		m.deviceDownloadUploadURL.SetTimeout(900000)
	endif
	    
' if a transfer is in progress, return
	if not m.deviceDownloadUploadURL.SetUrl(m.deviceDownloadURL) then
        m.diagnostics.PrintDebug("### UploadDeviceDownload - upload already in progress")
        if m.DeviceDownloadItemsPendingUpload.Count() > 100 then
            m.diagnostics.PrintDebug("### UploadDeviceDownload - clear pending items from queue")
            m.DeviceDownloadItemsPendingUpload.Clear()
        endif        
        if m.DeviceDownloadItems.Count() > 100 then
            m.diagnostics.PrintDebug("### UploadDeviceDownload - clear items from queue")
            m.DeviceDownloadItems.Clear()
        endif        
		return 
	else
        m.diagnostics.PrintDebug("### UploadDeviceDownload - proceed with post")
	end if

' generate the XML and upload the data
    root = CreateObject("roXMLElement")
    
    root.SetName("DeviceDownloadBatch")

	' first add the items that failed the last time
	for each deviceDownloadItem in m.DeviceDownloadItemsPendingUpload
		BuildDeviceDownloadItemXML(root, deviceDownloadItem)
    next

	' now add the new items
	for each deviceDownloadItem in m.DeviceDownloadItems    
		BuildDeviceDownloadItemXML(root, deviceDownloadItem)
    next

    xml = root.GenXML({ indent: " ", newline: chr(10), header: true })

' prepare the upload    
    contentDisposition$ = GetContentDisposition("UploadDeviceDownload.xml")
    m.AddUploadHeaders(m.deviceDownloadUploadURL, contentDisposition$)

	binding% = GetBinding(m.bsp.contentXfersEnabledWired, m.bsp.contentXfersEnabledWireless)
    m.diagnostics.PrintDebug("### Binding for UploadDeviceDownload is " + stri(binding%))
	ok = m.deviceDownloadUploadURL.BindToInterface(binding%)
	if not ok then stop

	ok = m.deviceDownloadUploadURL.AsyncPostFromString(xml)
    if not ok then
        m.diagnostics.PrintDebug("### UploadDeviceDownload - AsyncPostFromString failed")
    endif
        
	for each deviceDownloadItem in m.DeviceDownloadItems
		m.DeviceDownloadItemsPendingUpload.push(deviceDownloadItem)
	next

	m.DeviceDownloadItems.Clear()

End Sub


Sub BuildDeviceDownloadItemXML(root As Object, deviceDownloadItem As Object)

        item = root.AddBodyElement()
        item.SetName("deviceDownload")

        elem = item.AddElement("downloadEvent")
        elem.SetBody(deviceDownloadItem.downloadEvent$)
    
        elem = item.AddElement("fileName")
        elem.SetBody(deviceDownloadItem.fileName$)
    
        elem = item.AddElement("downloadData")
        elem.SetBody(deviceDownloadItem.downloadData$)

End Sub


Sub UploadLogFiles()

    if m.uploadLogFileURL$ = "" then return
    
' create roUrlTransfer if needed
	if type(m.uploadLogFileURLXfer) <> "roUrlTransfer" then
		m.uploadLogFileURLXfer = CreateObject("roUrlTransfer")
        m.uploadLogFileURLXfer.SetUrl(m.uploadLogFileURL$)
        m.uploadLogFileURLXfer.SetPort(m.msgPort)
	    m.uploadLogFileURLXfer.SetMinimumTransferRate(1,300)
	endif
	    
' if a transfer is in progress, return
    m.diagnostics.PrintDebug("### Upload " + m.uploadLogFolder)
	if not m.uploadLogFileURLXfer.SetUrl(m.uploadLogFileURL$) then
        m.diagnostics.PrintDebug("### Upload " + m.uploadLogFolder + " - upload already in progress")
		return 
	end if

' see if there are any files to upload
    listOfLogFiles = MatchFiles("/" + m.uploadLogFolder, "*.log")
    if listOfLogFiles.Count() = 0 then return
    
	binding% = GetBinding(m.bsp.logUploadsXfersEnabledWired, m.bsp.logUploadsXfersEnabledWireless)
    m.diagnostics.PrintDebug("### Binding for UploadLogFiles is " + stri(binding%))
	ok = m.uploadLogFileURLXfer.BindToInterface(binding%)

' upload the first file    
    for each file in listOfLogFiles
        m.diagnostics.PrintDebug("### UploadLogFiles " + file + " to " + m.uploadLogFileURL$)
        fullFilePath = m.uploadLogFolder + "/" + file
                
        contentDisposition$ = GetContentDisposition(file)
        m.AddUploadHeaders(m.uploadLogFileURLXfer, contentDisposition$)

        ok = m.uploadLogFileURLXfer.AsyncPostFromFile(fullFilePath)
        if not ok then
	        m.diagnostics.PrintDebug("### UploadLogFiles - AsyncPostFromFile failed")
        else
			m.logFileUpload = fullFilePath
			m.logFile$ = file
			return
        endif
    next
    
End Sub


Sub UploadLogFileHandler(msg As Object)
	    	    
    if msg.GetResponseCode() = 200 then

        if IsString(m.logFileUpload) then
            m.diagnostics.PrintDebug("###  UploadLogFile XferEvent - successfully uploaded " + m.logFileUpload)
            if m.enableLogDeletion then
                DeleteFile(m.logFileUpload)
            else
                target$ = m.uploadLogArchiveFolder + "/" + m.logFile$
                ok = MoveFile(m.logFileUpload, target$)
            endif
            m.logFileUpload = invalid		    
        endif
        
    else
        
        if IsString(m.logFileUpload) then
            m.diagnostics.PrintDebug("### Failed to upload log file " + m.logFileUpload + ", error code = " + str(msg.GetResponseCode()))

            ' move file so that the script doesn't try to upload it again immediately
            target$ = m.uploadLogFailedFolder + "/" + m.logFile$
            ok = MoveFile(m.logFileUpload, target$)

        endif

        m.logging.WriteDiagnosticLogEntry(m.diagnosticCodes.EVENT_LOGFILE_UPLOAD_FAILURE, str(msg.GetResponseCode()))
        
	endif
	
	m.UploadLogFiles()
		
End Sub


Function UploadTrafficDownload(contentDownloaded# As Double) As Boolean

    if m.trafficDownloadURL = "" then
        m.diagnostics.PrintDebug("### UploadTrafficDownload - trafficDownloadURL not set, return")
        return false
    else
        m.diagnostics.PrintDebug("### UploadTrafficDownload")
    endif
    
' create roUrlTransfer if needed
	if type(m.trafficDownloadUploadURL) <> "roUrlTransfer" then
		m.trafficDownloadUploadURL = CreateObject("roUrlTransfer")
        m.trafficDownloadUploadURL.SetUrl(m.trafficDownloadURL)
        m.trafficDownloadUploadURL.SetPort(m.msgPort)
	    m.trafficDownloadUploadURL.SetTimeout(900000)
	endif
	    
' if a transfer is in progress, return
	if not m.trafficDownloadUploadURL.SetUrl(m.trafficDownloadURL) then
        m.diagnostics.PrintDebug("### UploadTrafficDownload - upload already in progress")
		return false
	end if

    m.lastContentDownloaded# = contentDownloaded#
    
	binding% = GetBinding(m.bsp.contentXfersEnabledWired, m.bsp.contentXfersEnabledWireless)
    m.diagnostics.PrintDebug("### Binding for UploadTrafficDownload is " + stri(binding%))
	ok = m.trafficDownloadUploadURL.BindToInterface(binding%)
	if not ok then stop

	return m.SendTrafficUpload(m.trafficDownloadUploadURL, contentDownloaded#, false)

End Function


Function UploadMRSSTrafficDownload(contentDownloaded# As Double) As Boolean

    if m.trafficDownloadURL = "" then
        m.diagnostics.PrintDebug("### UploadMRSSTrafficDownload - trafficDownloadURL not set, return")
        return false
    else
        m.diagnostics.PrintDebug("### UploadMRSSTrafficDownload")
    endif
    
' create roUrlTransfer if needed
	if type(m.mrssTrafficDownloadUploadURL) <> "roUrlTransfer" then
		m.mrssTrafficDownloadUploadURL = CreateObject("roUrlTransfer")
        m.mrssTrafficDownloadUploadURL.SetUrl(m.trafficDownloadURL)
        m.mrssTrafficDownloadUploadURL.SetPort(m.msgPort)
	    m.mrssTrafficDownloadUploadURL.SetTimeout(900000)
	endif
	    
' if a transfer is in progress, return
	if not m.mrssTrafficDownloadUploadURL.SetUrl(m.trafficDownloadURL) then
        m.diagnostics.PrintDebug("### UploadMRSSTrafficDownload - upload already in progress")

		totalContentDownloaded# = m.pendingMRSSContentDownloaded#
		totalContentDownloaded# = totalContentDownloaded# + contentDownloaded#
		m.pendingMRSSContentDownloaded# = totalContentDownloaded#

		return false
	end if

	contentDownloaded# = contentDownloaded# + m.pendingMRSSContentDownloaded#
	m.pendingMRSSContentDownloaded# = 0
    m.lastMRSSContentDownloaded# = contentDownloaded#
    
	binding% = GetBinding(m.bsp.mediaFeedsXfersEnabledWired, m.bsp.mediaFeedsXfersEnabledWireless)
    m.diagnostics.PrintDebug("### Binding for UploadMRSSTrafficDownload is " + stri(binding%))
	ok = m.mrssTrafficDownloadUploadURL.BindToInterface(binding%)
	if not ok then stop

	m.diagnostics.PrintDebug("### UploadMRSSTrafficDownload: Content downloaded = " + str(contentDownloaded#))
	return m.SendTrafficUpload(m.mrssTrafficDownloadUploadURL, contentDownloaded#, true)

End Function


Sub SendTrafficUpload(url As Object, contentDownloaded# As Double, intermediateTrafficReport As Boolean) As Boolean

' convert contentDownloaded# to contentDownloaded in KBytes which can be stored in an integer
	contentDownloaded% = contentDownloaded# / 1024

	url.SetHeaders(m.currentSync.GetMetadata("server"))
    url.AddHeader("DeviceID", m.deviceUniqueID$)
    url.AddHeader("contentDownloadedInKBytes", StripLeadingSpaces(stri(contentDownloaded%)))    
    url.AddHeader("DeviceFWVersion", m.firmwareVersion$)
    url.AddHeader("DeviceSWVersion", m.autorunVersion$)
    url.AddHeader("CustomAutorunVersion", m.customAutorunVersion$)
    url.AddHeader("timezone", m.systemTime.GetTimeZone())
    url.AddHeader("utcTime", m.systemTime.GetUtcDateTime().GetString())
	if intermediateTrafficReport then
	    url.AddHeader("intermediateTrafficReport", "yes")
	endif

	ok = url.AsyncPostFromString("UploadTrafficDownload")
	if not ok then
        m.diagnostics.PrintDebug("### SendTrafficUpload - AsyncPostFromString failed")
		return false
	endif	

    return ok

End Sub


Sub AddEventItem(eventType$ As String, eventData$ As String, eventResponseCode$ As String)
    
    ' Make sure the array doesn't get too big.
    while m.EventItems.Count() > 50
        m.EventItems.Shift()
    end while

    eventItem = CreateObject("roAssociativeArray")
    eventItem.eventType$ = eventType$
    eventItem.eventData$ = eventData$
    eventItem.eventResponseCode$ = eventResponseCode$
    m.EventItems.push(eventItem)

    m.UploadEvent()
    
End Sub


Sub AddDeviceErrorItem(event$ As String, name$ As String, failureReason$ As String, responseCode$ As String)
    
    ' Make sure the array doesn't get too big.
    while m.DeviceErrorItems.Count() > 50
        m.DeviceErrorItems.Shift()
    end while

    deviceErrorItem = CreateObject("roAssociativeArray")
    deviceErrorItem.event$ = event$
    deviceErrorItem.name$ = name$
    deviceErrorItem.failureReason$ = failureReason$
    deviceErrorItem.responseCode$ = responseCode$
    m.DeviceErrorItems.push(deviceErrorItem)

    m.UploadDeviceError()
    
End Sub


Sub AddBatteryChargerItem(event$ As String, powerSource$ As String, batteryState$ As String, socPercentRange% As Integer)
    
    ' Make sure the array doesn't get too big.
    while m.BatteryChargerItems.Count() > 50
        m.BatteryChargerItems.Shift()
    end while

    batteryChargerItem = CreateObject("roAssociativeArray")
    batteryChargerItem.event$ = event$
    batteryChargerItem.powerSource$ = powerSource$
    batteryChargerItem.batteryState$ = batteryState$
    batteryChargerItem.socPercentRange$ = stri(socPercentRange%)
    m.BatteryChargerItems.push(batteryChargerItem)

    m.UploadBatteryCharger()
    
End Sub


Sub UploadBatteryCharger()

    m.diagnostics.PrintDebug("### UploadBatteryCharger")

' verify that there is content to upload
    if m.BatteryChargerItems.Count() = 0 then return
    
' create roUrlTransfer if needed
	if type(m.batteryChargerUploadURL) <> "roUrlTransfer" then
		m.batteryChargerUploadURL = CreateObject("roUrlTransfer")
        m.batteryChargerUploadURL.SetUrl(m.batteryChargerURL$)
        m.batteryChargerUploadURL.SetPort(m.msgPort)
	    m.batteryChargerUploadURL.SetTimeout(900000)
	endif
	    
' if a transfer is in progress, return
	if not m.batteryChargerUploadURL.SetUrl(m.batteryChargerURL$) then
        m.diagnostics.PrintDebug("### UploadBatteryCharger - upload already in progress")
        if m.BatteryChargerItems.Count() > 100 then
            m.diagnostics.PrintDebug("### UploadBatteryCharger - clear items from queue")
            m.BatteryChargerItems.Clear()
        endif        
		return 
	end if

' generate the XML and upload the data
    root = CreateObject("roXMLElement")
    
    root.SetName("BatteryChargerBatch")

    for each batteryChargerItem in m.BatteryChargerItems
    
        item = root.AddBodyElement()
        item.SetName("batteryCharger")

        elem = item.AddElement("event")
        elem.SetBody(batteryChargerItem.event$)
    
        elem = item.AddElement("powerSource")
        elem.SetBody(batteryChargerItem.powerSource$)
    
        elem = item.AddElement("batteryState")
        elem.SetBody(batteryChargerItem.batteryState$)
    
        elem = item.AddElement("socPercentRange")
        elem.SetBody(batteryChargerItem.socPercentRange$)
    
    next

    xml = root.GenXML({ indent: " ", newline: chr(10), header: true })

' prepare the upload    
    contentDisposition$ = GetContentDisposition("UploadBatteryCharger.xml")
    m.AddUploadHeaders(m.batteryChargerUploadURL, contentDisposition$)

	binding% = GetBinding(m.bsp.healthXfersEnabledWired, m.bsp.healthXfersEnabledWireless)
    m.diagnostics.PrintDebug("### Binding for battery charger is " + stri(binding%))
	ok = m.batteryChargerUploadURL.BindToInterface(binding%)
	if not ok then stop

	ok = m.batteryChargerUploadURL.AsyncPostFromString(xml)
    if not ok then
        m.diagnostics.PrintDebug("### UploadBatteryCharger - AsyncPostFromString failed")
    else
		' clear out BatteryChargerItems - no big deal if the post fails
		m.BatteryChargerItems.Clear()
    endif
    
End Sub


Sub UploadEvent()

    m.diagnostics.PrintDebug("### UploadEvent")

' verify that there is content to upload
    if m.EventItems.Count() = 0 then return
    
' create roUrlTransfer if needed
	if type(m.eventUploadURL) <> "roUrlTransfer" then
		m.eventUploadURL = CreateObject("roUrlTransfer")
	    m.eventUploadURL.SetUrl(m.eventURL)
        m.eventUploadURL.SetPort(m.msgPort)
	    m.eventUploadURL.SetTimeout(900000)
	endif
	    
' if a transfer is in progress, return
	if not m.eventUploadURL.SetUrl(m.eventURL) then
        m.diagnostics.PrintDebug("### UploadEvent - upload already in progress")
        if m.EventItems.Count() > 50 then
            m.diagnostics.PrintDebug("### UploadEvent - clear items from queue")
            m.EventItems.Clear()
        endif        
		return 
	end if

' generate the XML and upload the data
    root = CreateObject("roXMLElement")
    
    root.SetName("EventBatch")

    for each eventItem in m.EventItems
    
        item = root.AddBodyElement()
        item.SetName("event")

        elem = item.AddElement("eventType")
        elem.SetBody(eventItem.eventType$)
    
        elem = item.AddElement("eventData")
        elem.SetBody(eventItem.eventData$)
    
        elem = item.AddElement("eventResponseCode")
        elem.SetBody(eventItem.eventResponseCode$)
    
    next

    xml = root.GenXML({ indent: " ", newline: chr(10), header: true })

' prepare the upload    
    contentDisposition$ = GetContentDisposition("UploadEvent.xml")
    m.AddUploadHeaders(m.eventUploadURL, contentDisposition$)

	binding% = GetBinding(m.bsp.contentXfersEnabledWired, m.bsp.contentXfersEnabledWireless)
    m.diagnostics.PrintDebug("### Binding for UploadEvent is " + stri(binding%))
	ok = m.eventUploadURL.BindToInterface(binding%)
	if not ok then stop

	ok = m.eventUploadURL.AsyncPostFromString(xml)
    if not ok then
        m.diagnostics.PrintDebug("### UploadEvent - AsyncPostFromString failed")
	else
		' clear out EventItems - no big deal if the post fails
		m.EventItems.Clear()
	endif
        
End Sub


Sub UploadDeviceError()

    m.diagnostics.PrintDebug("### UploadDeviceError")

' verify that there is content to upload
    if m.DeviceErrorItems.Count() = 0 then return
    
' create roUrlTransfer if needed
	if type(m.deviceErrorUploadURL) <> "roUrlTransfer" then
		m.deviceErrorUploadURL = CreateObject("roUrlTransfer")
	    m.deviceErrorUploadURL.SetUrl(m.deviceErrorURL)
        m.deviceErrorUploadURL.SetPort(m.msgPort)
	    m.deviceErrorUploadURL.SetTimeout(900000)
	endif
	    
' if a transfer is in progress, return
	if not m.deviceErrorUploadURL.SetUrl(m.deviceErrorURL) then
        m.diagnostics.PrintDebug("### UploadDeviceError - upload already in progress")
        if m.DeviceErrorItems.Count() > 50 then
            m.diagnostics.PrintDebug("### UploadDeviceError - clear items from queue")
            m.DeviceErrorItems.Clear()
        endif        
		return 
	end if

' generate the XML and upload the data
    root = CreateObject("roXMLElement")
    
    root.SetName("DeviceErrorBatch")

    for each deviceErrorItem in m.DeviceErrorItems
    
        item = root.AddBodyElement()
        item.SetName("deviceError")

        elem = item.AddElement("event")
        elem.SetBody(deviceErrorItem.event$)
    
        elem = item.AddElement("name")
        elem.SetBody(deviceErrorItem.name$)
    
        elem = item.AddElement("failureReason")
        elem.SetBody(deviceErrorItem.failureReason$)
    
        elem = item.AddElement("responseCode")
        elem.SetBody(deviceErrorItem.responseCode$)
    
    next

    xml = root.GenXML({ indent: " ", newline: chr(10), header: true })

' prepare the upload    
    contentDisposition$ = GetContentDisposition("UploadDeviceError.xml")
    m.AddUploadHeaders(m.deviceErrorUploadURL, contentDisposition$)

	binding% = GetBinding(m.bsp.contentXfersEnabledWired, m.bsp.contentXfersEnabledWireless)
    m.diagnostics.PrintDebug("### Binding for UploadDeviceError is " + stri(binding%))
	ok = m.deviceErrorUploadURL.BindToInterface(binding%)
	if not ok then stop

	ok = m.deviceErrorUploadURL.AsyncPostFromString(xml)
    if not ok then
        m.diagnostics.PrintDebug("### UploadDeviceError - AsyncPostFromString failed")
    else
		' clear out DeviceErrorItems - no big deal if the post fails
		m.DeviceErrorItems.Clear()
    endif
        
End Sub


Function STNetworkSchedulerEventHandler(event As Object, stateData As Object) As Object

    stateData.nextState = invalid
    
    if type(event) = "roAssociativeArray" then      ' internal message event

        if IsString(event["EventType"]) then
        
            if event["EventType"] = "ENTRY_SIGNAL" then
            
                m.bsp.diagnostics.PrintDebug(m.id$ + ": entry signal")

				currentTime = m.stateMachine.systemTime.GetLocalDateTime()

				' set timer for when content download window starts / ends
				if m.stateMachine.contentDownloadsRestricted then
					startOfRange% = m.stateMachine.contentDownloadRangeStart%
					endOfRange% = startOfRange% + m.stateMachine.contentDownloadRangeLength%
            
					notInDownloadWindow = OutOfDownloadWindow(currentTime, startOfRange%, endOfRange%)

					if notInDownloadWindow then
						m.stateMachine.RestartContentDownloadWindowStartTimer(currentTime, startOfRange%)
					else
						m.stateMachine.RestartContentDownloadWindowEndTimer(currentTime, endOfRange%)
					endif

				endif

				' set timer for when heartbeat window starts / ends
				if m.stateMachine.timeBetweenHearbeats% > 0 then

					if m.stateMachine.heartbeatsRestricted then
						startOfRange% = m.stateMachine.heartbeatsRangeStart%
						endOfRange% = startOfRange% + m.stateMachine.heartbeatsRangeLength%
            
						notInHeartbeatWindow = OutOfDownloadWindow(currentTime, startOfRange%, endOfRange%)

						if notInHeartbeatWindow then
							m.stateMachine.RestartHeartbeatsWindowStartTimer(currentTime, startOfRange%)
						else
							' in window, send initial heartbeat
							m.stateMachine.SendHeartbeat()		
							m.stateMachine.RestartHeartbeatsWindowEndTimer(currentTime, endOfRange%)
						endif
					else
						m.stateMachine.SendHeartbeat()		
					endif

				endif

                return "HANDLED"

            else if event["EventType"] = "EXIT_SIGNAL" then

                m.bsp.diagnostics.PrintDebug(m.id$ + ": exit signal")
            
            endif
            
        endif
        
    else if type(event) = "roTimerEvent" then
    
		if type(m.heartbeatTimer) = "roTimer" then

            if stri(event.GetSourceIdentity()) = stri(m.heartbeatTimer.GetIdentity()) then

				time = m.stateMachine.systemTime.GetLocalDateTime()
				if m.stateMachine.heartbeatsRestricted then
					startOfRange% = m.stateMachine.heartbeatsRangeStart%
					endOfRange% = startOfRange% + m.stateMachine.heartbeatsRangeLength%
            
					notInHeartbeatWindow = OutOfDownloadWindow(time, startOfRange%, endOfRange%)

					if not notInHeartbeatWindow then
						m.stateMachine.SendHeartbeat()		
					endif
				else
					m.stateMachine.SendHeartbeat()		
				endif

				return "HANDLED"

			endif
					
		endif

        if type(m.stateMachine.heartbeatsWindowStartTimer) = "roTimer" then
        
            if stri(event.GetSourceIdentity()) = stri(m.stateMachine.heartbeatsWindowStartTimer.GetIdentity()) then

				' start window end timer
				if m.stateMachine.heartbeatsRestricted then

					currentTime = m.stateMachine.systemTime.GetLocalDateTime()
					startOfRange% = m.stateMachine.heartbeatsRangeStart%
					endOfRange% = startOfRange% + m.stateMachine.heartbeatsRangeLength%

					m.stateMachine.RestartHeartbeatsWindowEndTimer(currentTime, endOfRange%)

				endif

		        return "HANDLED"
		    endif
		    
		endif

        if type(m.stateMachine.heartbeatsWindowEndTimer) = "roTimer" then
        
            if stri(event.GetSourceIdentity()) = stri(m.stateMachine.heartbeatsWindowEndTimer.GetIdentity()) then

				' start window start timer
				currentTime = m.stateMachine.systemTime.GetLocalDateTime()
				startOfRange% = m.stateMachine.heartbeatsRangeStart%
				endOfRange% = startOfRange% + m.stateMachine.heartbeatsRangeLength%

				m.stateMachine.RestartHeartbeatsWindowStartTimer(currentTime, startOfRange%)

		        return "HANDLED"
		    endif
		    
		endif

        if type(m.stateMachine.contentDownloadWindowStartTimer) = "roTimer" then
        
            if stri(event.GetSourceIdentity()) = stri(m.stateMachine.contentDownloadWindowStartTimer.GetIdentity()) then

				SetDownloadRateLimit(m.bsp.diagnostics, 0, m.stateMachine.wiredRateLimits.rlInWindow%)

				if m.stateMachine.useWireless then
					SetDownloadRateLimit(m.bsp.diagnostics, 1, m.stateMachine.wirelessRateLimits.rlInWindow%)
				endif
                
				' start window end timer
				if m.stateMachine.contentDownloadsRestricted then

					currentTime = m.stateMachine.systemTime.GetLocalDateTime()
					startOfRange% = m.stateMachine.contentDownloadRangeStart%
					endOfRange% = startOfRange% + m.stateMachine.contentDownloadRangeLength%

					m.stateMachine.RestartContentDownloadWindowEndTimer(currentTime, endOfRange%)

				endif

		        return "HANDLED"
		    endif
		    
		endif

        if type(m.stateMachine.contentDownloadWindowEndTimer) = "roTimer" then
        
            if stri(event.GetSourceIdentity()) = stri(m.stateMachine.contentDownloadWindowEndTimer.GetIdentity()) then

				' send internal message to indicate that any in-progress sync pool downloads should stop
				cancelDownloadsEvent = CreateObject("roAssociativeArray")
				cancelDownloadsEvent["EventType"] = "CANCEL_DOWNLOADS"
				m.stateMachine.msgPort.PostMessage(cancelDownloadsEvent)

				' change rate limit values - outside window
				SetDownloadRateLimit(m.bsp.diagnostics, 0, m.stateMachine.wiredRateLimits.rlOutsideWindow%)

				if m.stateMachine.useWireless then
					SetDownloadRateLimit(m.bsp.diagnostics, 1, m.stateMachine.wirelessRateLimits.rlOutsideWindow%)
				endif

				' start window start timer
				currentTime = m.stateMachine.systemTime.GetLocalDateTime()
				startOfRange% = m.stateMachine.contentDownloadRangeStart%
				endOfRange% = startOfRange% + m.stateMachine.contentDownloadRangeLength%

				m.stateMachine.RestartContentDownloadWindowStartTimer(currentTime, startOfRange%)

		        return "HANDLED"
		    endif
		    
		endif

    else if type(event) = "roUrlEvent" then
        
		if type (m.stateMachine.sendHeartbeatUrl) = "roUrlTransfer" then
	        if event.GetSourceIdentity() = m.stateMachine.sendHeartbeatUrl.GetIdentity() then

				m.bsp.diagnostics.PrintDebug("###  SendHeartbeatUrlEvent: " + stri(event.GetResponseCode()))

				if event.GetResponseCode() = 200 then
					m.stateMachine.numHeartbeatRetries% = 0
				    m.stateMachine.currentTimeBetweenHeartbeats% = m.stateMachine.timeBetweenHearbeats%
				else
					m.stateMachine.ResetHeartbeatTimerToDoRetry()
				endif

				' start heartbeat timer
				newTimeout = m.stateMachine.systemTime.GetLocalDateTime()
				newTimeout.AddSeconds(m.stateMachine.currentTimeBetweenHeartbeats%)
				if type(m.heartbeatTimer) <> "roTimer" then
					m.heartbeatTimer = CreateObject("roTimer")
					m.heartbeatTimer.SetPort(m.stateMachine.msgPort)
				endif
				m.heartbeatTimer.SetDateTime(newTimeout)
				m.heartbeatTimer.Start()

				return "HANDLED"
	        endif
        endif

        if type (m.stateMachine.deviceDownloadUploadURL) = "roUrlTransfer" then
	        if event.GetSourceIdentity() = m.stateMachine.deviceDownloadUploadURL.GetIdentity() then
				if event.GetResponseCode() = 200 then
					m.stateMachine.DeviceDownloadItemsPendingUpload.Clear()
				else
					m.bsp.diagnostics.PrintDebug("###  DeviceDownloadURLEvent: " + stri(event.GetResponseCode()))
				endif
				m.stateMachine.deviceDownloadUploadURL = invalid
				m.stateMachine.UploadDeviceDownload()
				return "HANDLED"
	        endif
        endif

        if type (m.stateMachine.deviceDownloadProgressUploadURL) = "roUrlTransfer" then
	        if event.GetSourceIdentity() = m.stateMachine.deviceDownloadProgressUploadURL.GetIdentity() then
				if event.GetResponseCode() = 200 then
					m.stateMachine.DeviceDownloadProgressItemsPendingUpload.Clear()
				else
					m.bsp.diagnostics.PrintDebug("###  DeviceDownloadProgressURLEvent: " + stri(event.GetResponseCode()))
				endif
				m.stateMachine.deviceDownloadProgressUploadURL = invalid
				m.stateMachine.UploadDeviceDownloadProgressItems()
				return "HANDLED"
	        endif
        endif

        if type (m.stateMachine.uploadLogFileURLXfer) = "roUrlTransfer" then
	        if event.GetSourceIdentity() = m.stateMachine.uploadLogFileURLXfer.GetIdentity() then
				m.stateMachine.uploadLogFileURLXfer = invalid
	            m.stateMachine.UploadLogFileHandler(event)
                return "HANDLED"
	        endif
        endif

        if type (m.stateMachine.eventUploadURL) = "roUrlTransfer" then
	        if event.GetSourceIdentity() = m.stateMachine.eventUploadURL.GetIdentity() then
			    m.stateMachine.eventUploadURL = invalid
	            m.stateMachine.UploadEvent()
                return "HANDLED"
	        endif
        endif

        if type (m.stateMachine.deviceErrorUploadURL) = "roUrlTransfer" then
	        if event.GetSourceIdentity() = m.stateMachine.deviceErrorUploadURL.GetIdentity() then
			    m.stateMachine.deviceErrorUploadURL = invalid
	            m.stateMachine.UploadDeviceError()
                return "HANDLED"
	        endif
        endif

        if type (m.stateMachine.batteryChargerUploadURL) = "roUrlTransfer" then
	        if event.GetSourceIdentity() = m.stateMachine.batteryChargerUploadURL.GetIdentity() then
			    m.stateMachine.batteryChargerUploadURL = invalid
	            m.stateMachine.UploadBatteryCharger()
                return "HANDLED"
	        endif
        endif

		if type (m.stateMachine.trafficDownloadUploadURL) = "roUrlTransfer" then
			if event.GetSourceIdentity() = m.stateMachine.trafficDownloadUploadURL.GetIdentity() then
				if event.GetInt() = m.URL_EVENT_COMPLETE then
					m.bsp.diagnostics.PrintDebug("###  URLTrafficDownloadXferEvent: " + stri(event.GetResponseCode()))
					m.stateMachine.trafficDownloadUploadURL = invalid
					if event.GetResponseCode() <> 200 then
						m.stateMachine.UploadTrafficDownload(m.lastContentDownloaded#)
					endif
			    endif
                return "HANDLED"
			endif
		endif
    
		if type (m.stateMachine.mrssTrafficDownloadUploadURL) = "roUrlTransfer" then
			if event.GetSourceIdentity() = m.stateMachine.mrssTrafficDownloadUploadURL.GetIdentity() then
				if event.GetInt() = m.URL_EVENT_COMPLETE then
					m.bsp.diagnostics.PrintDebug("###  URLMRSSTrafficDownloadXferEvent: " + stri(event.GetResponseCode()))
					m.stateMachine.mrssTrafficDownloadUploadURL = invalid
					if event.GetResponseCode() <> 200 then
						m.stateMachine.UploadMRSSTrafficDownload(m.lastMRSSContentDownloaded#)
					endif
			    endif
                return "HANDLED"
			endif
		endif

    endif
            
    stateData.nextState = m.superState
    return "SUPER"
    
End Function


Sub RestartWindowStartTimer(timer As Object, currentTime As Object, startOfRange% As Integer)

	hour% = startOfRange% / 60
	minute% = startOfRange% - (hour% * 60)
	timeoutTime = CopyDateTime(currentTime)
	timeoutTime.SetHour(hour%)
	timeoutTime.SetMinute(minute%)
	timeoutTime.SetSecond(0)
	timeoutTime.SetMillisecond(0)
	GetNextTimeout(m.systemTime, timeoutTime)
	timer.SetDateTime(timeoutTime)
	timer.SetPort(m.msgPort)
	timer.Start()

	m.bsp.diagnostics.PrintDebug("RestartWindowStartTimer: set timer to start of window - " + timeoutTime.GetString())

End Sub


Sub RestartContentDownloadWindowStartTimer(currentTime As Object, startOfRange% As Integer)
	m.contentDownloadWindowStartTimer = CreateObject("roTimer")
	m.RestartWindowStartTimer(m.contentDownloadWindowStartTimer, currentTime, startOfRange%)
End Sub


Sub RestartHeartbeatsWindowStartTimer(currentTime As Object, startOfRange% As Integer)
	m.heartbeatsWindowStartTimer = CreateObject("roTimer")
	m.RestartWindowStartTimer(m.heartbeatsWindowStartTimer, currentTime, startOfRange%)
End Sub


Function RestartWindowEndTimer(currentTime As Object, endOfRange% As Integer) As Object

	currentTime.SetHour(0)
	currentTime.SetMinute(0)
	currentTime.SetSecond(0)
	currentTime.SetMillisecond(0)
	currentTime.AddSeconds(endOfRange% * 60)
	currentTime.Normalize()
	GetNextTimeout(m.systemTime, currentTime)
	timer = CreateObject("roTimer")
	timer.SetDateTime(currentTime)
	timer.SetPort(m.msgPort)
	timer.Start()

	m.bsp.diagnostics.PrintDebug("RestartWindowEndTimer: set timer to end of window - " + currentTime.GetString())

	return timer

End Function


Sub RestartContentDownloadWindowEndTimer(currentTime As Object, endOfRange% As Integer)
	m.contentDownloadWindowEndTimer = m.RestartWindowEndTimer(currentTime, endOfRange%)
End Sub


Sub RestartHeartbeatsWindowEndTimer(currentTime As Object, endOfRange% As Integer)
	m.heartbeatsWindowEndTimer = m.RestartWindowEndTimer(currentTime, endOfRange%)
End Sub


Sub GetNextTimeout(systemTime As Object, timerDateTime As object) As Object

	currentDateTime = systemTime.GetLocalDateTime()

	if timerDateTime.GetString() <= currentDateTime.GetString() then
		timerDateTime.AddSeconds(24 * 60 * 60)
		timerDateTime.Normalize()
	endif
	
End Sub


Sub WaitForTransfersToComplete()

    if type(m.trafficDownloadUploadURL) = "roUrlTransfer" then    
        ' check to see if the trafficUpload call has been processed - if not, wait 5 seconds
        if not m.trafficDownloadUploadURL.SetUrl(m.trafficDownloadURL) then
            m.diagnostics.PrintDebug("### RebootAfterEventsSent - traffic upload still in progress - wait")
            sleep(5000)
            m.diagnostics.PrintDebug("### RebootAfterEventsSent - proceed after waiting 5 seconds for traffic upload to complete")
        else
            m.diagnostics.PrintDebug("### RebootAfterEventsSent - traffic upload must be complete - proceed")
        end if
    endif

    if type(m.deviceDownloadProgressUploadURL) = "roUrlTransfer" then    
        ' check to see if the device download progress call has been processed - if not, wait 5 seconds
	    if not m.deviceDownloadProgressUploadURL.SetUrl(m.deviceDownloadProgressURL) then
            sleep(5000)
            m.diagnostics.PrintDebug("### RebootAfterEventsSent - proceed after waiting 5 seconds for device download progress item upload to complete")
        else
            m.diagnostics.PrintDebug("### RebootAfterEventsSent - device download progress item upload must be complete - proceed")
        end if
    endif
    
    if type(m.deviceDownloadUploadURL) = "roUrlTransfer" then
        ' check to see if the device download call has been processed - if not, wait 5 seconds
	    if not m.deviceDownloadUploadURL.SetUrl(m.deviceDownloadURL) then
            sleep(5000)
            m.diagnostics.PrintDebug("### RebootAfterEventsSent - proceed after waiting 5 seconds for device download upload to complete")
        else
            m.diagnostics.PrintDebug("### RebootAfterEventsSent - device download upload must be complete - proceed")
        end if
    endif

End Sub


Sub RebootAfterEventsSent()

    ' temporary
    sleep(2000)
    
    m.WaitForTransfersToComplete()
    
	m.UploadDeviceDownloadProgressItems()    
	m.UploadDeviceDownload()
    
    m.WaitForTransfersToComplete()
    
    RebootSystem()

End Sub


Sub ResetDownloadTimerToDoRetry()

	if m.numRetries% >= m.maxRetries% then
	    m.diagnostics.PrintDebug("### reset_download_timer_to_do_retry - max retries attempted - wait until next regularly scheduled download.")
		m.numRetries% = 0
		m.currentTimeBetweenNetConnects% = m.timeBetweenNetConnects%
	else
		m.numRetries% = m.numRetries% + 1
		m.currentTimeBetweenNetConnects% = m.retryInterval% * m.numRetries%
	    m.diagnostics.PrintDebug("### reset_download_timer_to_do_retry - wait " + stri(m.currentTimeBetweenNetConnects%) + " seconds.")
	endif
	    
	m.syncPool = invalid

End Sub


Sub ResetHeartbeatTimerToDoRetry()

	if m.numHeartbeatRetries% >= m.maxHeartbeatRetries% then
	    m.diagnostics.PrintDebug("### reset_heartbeat_timer_to_do_retry - max retries attempted - wait until next regularly scheduled heartbeat.")
		m.numHeartbeatRetries% = 0
		m.currentTimeBetweenHeartbeats% = m.timeBetweenHearbeats%
	else
		m.numHeartbeatRetries% = m.numHeartbeatRetries% + 1
		m.currentTimeBetweenHeartbeats% = m.heartbeatRetryInterval% * m.numHeartbeatRetries%
	    m.diagnostics.PrintDebug("### reset_heartbeat_timer_to_do_retry - wait " + stri(m.currentTimeBetweenHeartbeats%) + " seconds.")
	endif
	    
End Sub


Function STWaitForTimeoutEventHandler(event As Object, stateData As Object) As Object

    stateData.nextState = invalid
    
    if type(event) = "roAssociativeArray" then      ' internal message event

        if IsString(event["EventType"]) then
        
            if event["EventType"] = "ENTRY_SIGNAL" then
            
                m.bsp.diagnostics.PrintDebug(m.id$ + ": entry signal")

				newTimeout = m.stateMachine.systemTime.GetLocalDateTime()
				newTimeout.AddSeconds(m.stateMachine.currentTimeBetweenNetConnects%)
				m.stateMachine.networkTimerDownload.timer.SetDateTime(newTimeout)
				m.stateMachine.networkTimerDownload.timer.Start()
				
                return "HANDLED"

            else if event["EventType"] = "EXIT_SIGNAL" then

                m.bsp.diagnostics.PrintDebug(m.id$ + ": exit signal")
            
            endif
            
        endif
        
    else if type(event) = "roTimerEvent" then
    
        if type(m.stateMachine.networkTimerDownload.timer) = "roTimer" then
        
            if stri(event.GetSourceIdentity()) = stri(m.stateMachine.networkTimerDownload.timer.GetIdentity()) then
        	    stateData.nextState = m.stateMachine.stRetrievingSyncList
		        return "TRANSITION"
    		    
		    endif
		    
		endif

    endif
            
    stateData.nextState = m.superState
    return "SUPER"
    
End Function


Function STRetrievingSyncListEventHandler(event As Object, stateData As Object) As Object

    stateData.nextState = invalid
    
    if type(event) = "roAssociativeArray" then      ' internal message event

        if IsString(event["EventType"]) then
        
            if event["EventType"] = "ENTRY_SIGNAL" then
            
                m.bsp.diagnostics.PrintDebug(m.id$ + ": entry signal")

                m.StartSync("download")

                return "HANDLED"

            else if event["EventType"] = "EXIT_SIGNAL" then

                m.bsp.diagnostics.PrintDebug(m.id$ + ": exit signal")
            
            endif
            
        endif
        
    else if type(event) = "roUrlEvent" then
    
        m.bsp.diagnostics.PrintDebug("STRetrievingSyncListEventHandler: roUrlEvent")

        if stri(event.GetSourceIdentity()) = stri(m.xfer.GetIdentity()) then
        
            stateData.nextState = m.SyncSpecXferEvent(event)
		    return "TRANSITION"
		    
		endif

    endif
            
    stateData.nextState = m.superState
    return "SUPER"
    
End Function


Sub SendHeartbeat()

	if m.heartbeatURL$ = "" then
        m.bsp.diagnostics.PrintDebug("### SendHeartbeat - heartbeatURL not set, return")
		return
	endif
		
    m.bsp.diagnostics.PrintTimestamp()
    m.bsp.diagnostics.PrintDebug("### SendHeartbeat")

	m.sendHeartbeatUrl = CreateObject("roUrlTransfer")
	m.sendHeartbeatUrl.SetPort(m.msgPort)

	m.sendHeartbeatUrl.SetUrl(m.heartbeatURL$)
	m.sendHeartbeatUrl.SetTimeout(90000) ' 90 second timeout

' Add minimum number of headers
	m.sendHeartbeatUrl.AddHeader("act", m.currentSync.LookupMetadata("server", "account"))
	m.sendHeartbeatUrl.AddHeader("pwd", m.currentSync.LookupMetadata("server", "password"))
	m.sendHeartbeatUrl.AddHeader("g", m.currentSync.LookupMetadata("server", "group"))
	m.sendHeartbeatUrl.AddHeader("u", m.currentSync.LookupMetadata("server", "user"))
	m.sendHeartbeatUrl.AddHeader("id", m.deviceUniqueID$)
	m.sendHeartbeatUrl.AddHeader("model", m.deviceModel$)
	m.sendHeartbeatUrl.AddHeader("family", m.deviceFamily$)
	m.sendHeartbeatUrl.AddHeader("fw", m.firmwareVersion$)
	m.sendHeartbeatUrl.AddHeader("sw", m.autorunVersion$)
	m.sendHeartbeatUrl.AddHeader("ca", m.customAutorunVersion$)
	m.sendHeartbeatUrl.AddHeader("tz", m.systemTime.GetTimeZone())

' card size
	du = CreateObject("roStorageInfo", "./")
	m.sendHeartbeatUrl.AddHeader("sz", str(du.GetSizeInMegabytes()))
	du = invalid

' presentation name
    if type(m.bsp.sign) = "roAssociativeArray" then
        m.sendHeartbeatUrl.AddHeader("pName", m.bsp.sign.name$)
    else
        m.sendHeartbeatUrl.AddHeader("pName", "none")
    endif
    
	binding% = GetBinding(m.bsp.healthXfersEnabledWired, m.bsp.healthXfersEnabledWireless)
    m.bsp.diagnostics.PrintDebug("### Binding for Heartbeat is " + stri(binding%))
	ok = m.sendHeartbeatUrl.BindToInterface(binding%)
	if not ok then stop

    if not m.sendHeartbeatUrl.AsyncGetToString() then stop

End Sub


Sub StartSync(syncType$ As String)

' Call when you want to start a sync operation

    m.bsp.diagnostics.PrintTimestamp()
    
    m.bsp.diagnostics.PrintDebug("### start_sync " + syncType$)
    
	if type(m.stateMachine.syncPool) = "roSyncPool" then
' This should be improved in the future to work out
' whether the sync spec we're currently satisfying
' matches the one that we're currently downloading or
' not.
        m.bsp.diagnostics.PrintDebug("### sync already active so we'll let it continue")
        m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_SYNC_ALREADY_ACTIVE, "")
		return
	endif

    if syncType$ = "cache" then
        if not m.stateMachine.proxy_mode then
            m.bsp.diagnostics.PrintDebug("### cache download requested but the BrightSign is not configured to use a cache server")
            return
        endif
    endif
    
	m.xfer = CreateObject("roUrlTransfer")
	m.xfer.SetPort(m.stateMachine.msgPort)
	
	m.stateMachine.syncType$ = syncType$

    m.bsp.diagnostics.PrintDebug("### xfer created - identity = " + stri(m.xfer.GetIdentity()) + " ###")

' We've read in our current sync. Talk to the server to get
' the next sync. Note that we use the current-sync.xml because
' we need to tell the server what we are _currently_ running not
' what we might be running at some point in the future.

    base$ = m.stateMachine.currentSync.LookupMetadata("client", "base")
    nextURL = GetURL(base$, m.stateMachine.currentSync.LookupMetadata("client", "next"))
    m.bsp.diagnostics.PrintDebug("### Looking for new sync list from " + nextURL)    
    m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_CHECK_CONTENT, nextURL)

	m.xfer.SetUrl(nextURL)
    if m.stateMachine.setUserAndPassword then m.xfer.SetUserAndPassword(m.stateMachine.user$, m.stateMachine.password$)
	m.xfer.EnableUnsafeAuthentication(m.stateMachine.enableUnsafeAuthentication)
    m.xfer.SetMinimumTransferRate(10,240)
	m.xfer.SetHeaders(m.stateMachine.currentSync.GetMetadata("server"))

' Add presentation name to header
    if type(m.bsp.sign) = "roAssociativeArray" then
        m.xfer.AddHeader("presentationName", m.bsp.sign.name$)
    else
        m.xfer.AddHeader("presentationName", "none")
    endif
    
' Add device unique identifier, timezone
    m.xfer.AddHeader("DeviceID", m.stateMachine.deviceUniqueID$)
    m.xfer.AddHeader("DeviceModel", m.stateMachine.deviceModel$)
    m.xfer.AddHeader("DeviceFamily", m.stateMachine.deviceFamily$)
    m.xfer.AddHeader("DeviceFWVersion", m.stateMachine.firmwareVersion$)
    m.xfer.AddHeader("DeviceSWVersion", m.stateMachine.autorunVersion$)
    m.xfer.AddHeader("CustomAutorunVersion", m.stateMachine.customAutorunVersion$)
    m.xfer.AddHeader("timezone", m.stateMachine.systemTime.GetTimeZone())
    m.xfer.AddHeader("localTime", m.stateMachine.systemTime.GetLocalDateTime().GetString())

    m.stateMachine.AddMiscellaneousHeaders(m.xfer)

	binding% = GetBinding(m.bsp.contentXfersEnabledWired, m.bsp.contentXfersEnabledWireless)
    m.bsp.diagnostics.PrintDebug("### Binding for StartSync is " + stri(binding%))
	ok = m.xfer.BindToInterface(binding%)
	if not ok then stop

    if not m.xfer.AsyncGetToObject("roSyncSpec") then stop
    
End Sub


Sub AddMiscellaneousHeaders(urlXfer As Object)

' Add card size
	du = CreateObject("roStorageInfo", "./")
	urlXfer.AddHeader("storage-size", str(du.GetSizeInMegabytes()))
	urlXfer.AddHeader("storage-fs", du.GetFileSystemType())

' Add estimated realized size
	tempPool = CreateObject("roSyncPool", "pool")
	tempSpec = CreateObject("roSyncSpec")
	if tempSpec.ReadFromFile("current-sync.xml") then
	    urlXfer.AddHeader("storage-current-used", str(tempPool.EstimateRealizedSizeInMegabytes(tempSpec, "./")))
	endif
	tempPool = invalid
	tempSpec = invalid
    
End Sub


Function SyncSpecXferEvent(event As Object) As Object

    nextState = invalid
    
	xferInUse = false
	
	if event.GetResponseCode() = 200 then
	
        m.stateMachine.newSync = event.GetObject()
    			    
        m.bsp.diagnostics.PrintDebug("### Spec received from server")
        
        ' check for a forced reboot
        forceReboot$ = LCase(m.stateMachine.newSync.LookupMetadata("client", "forceReboot"))
        if forceReboot$ = "true" then
            m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_SYNCSPEC_RECEIVED, "FORCE REBOOT")
            m.stateMachine.logging.FlushLogFile()
	        a=RebootSystem()
            stop
        endif
        
        ' check for forced log upload
        forceLogUpload$ = LCase(m.stateMachine.newSync.LookupMetadata("client", "forceLogUpload"))
        if forceLogUpload$ = "true" then
            m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_SYNCSPEC_RECEIVED, "FORCE LOG UPLOAD")
            m.stateMachine.logging.CutoverLogFile(true)
			m.bsp.LogActivePresentation()
        endif
        
	    if m.stateMachine.newSync.EqualTo(m.stateMachine.currentSync) then
            m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_SYNCSPEC_RECEIVED, "NO")
            m.bsp.diagnostics.PrintDebug("### Server has given us a spec that matches current-sync. Nothing more to do.")
            m.stateMachine.AddDeviceDownloadItem("SyncSpecUnchanged", "", "")
		    m.stateMachine.newSync = invalid
		    m.stateMachine.numRetries% = 0
		    m.stateMachine.currentTimeBetweenNetConnects% = m.stateMachine.timeBetweenNetConnects%

			' if necessary, upload the list of current files to the server
			if m.stateMachine.FileListPendingUpload then
				m.stateMachine.BuildFileDownloadList(m.stateMachine.currentSync)
				m.stateMachine.UploadDeviceDownloadProgressFileList()
				m.stateMachine.FileListPendingUpload = false
			endif

            return m.stateMachine.stWaitForTimeout
	    endif
        badReadySync = CreateObject("roSyncSpec")
	    if badReadySync.ReadFromFile("bad-sync.xml") then
		    if m.stateMachine.newSync.EqualTo(badReadySync) then
                m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_SYNCSPEC_RECEIVED, "BAD SYNC")
                m.bsp.diagnostics.PrintDebug("### Server has given us a spec that matches bad-sync. Nothing more to do.")
			    badReadySync = invalid
			    m.stateMachine.newSync = invalid
			    m.stateMachine.numRetries% = 0
			    m.stateMachine.currentTimeBetweenNetConnects% = m.stateMachine.timeBetweenNetConnects%
				return m.stateMachine.stWaitForTimeout
		    endif
	    endif

        m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_SYNCSPEC_RECEIVED, "YES")

        m.stateMachine.syncPoolFiles = CreateObject("roSyncPoolFiles", "pool", m.stateMachine.newSync)

		m.stateMachine.BuildFileDownloadList(m.stateMachine.newSync)
        m.stateMachine.UploadDeviceDownloadProgressFileList()
		m.stateMachine.FileListPendingUpload = false
        m.stateMachine.AddDeviceDownloadItem("SyncSpecDownloadStarted", "", "")
                                                
        m.stateMachine.contentDownloaded# = 0

' Retrieve network connection priorities from the sync spec
		networkConnectionPriorityWired$ = m.stateMachine.newSync.LookupMetadata("client", "networkConnectionPriorityWired")
		if networkConnectionPriorityWired$ <> "" then
			networkConnectionPriorityWired% = int(val(networkConnectionPriorityWired$))
			nc = CreateObject("roNetworkConfiguration", 0)
			if type(nc) = "roNetworkConfiguration" then
				nc.SetRoutingMetric(networkConnectionPriorityWired%)
				nc.Apply()
				nc = invalid
			endif
		endif

		networkConnectionPriorityWireless$ = m.stateMachine.newSync.LookupMetadata("client", "networkConnectionPriorityWireless")
		if networkConnectionPriorityWireless$ <> "" then
			networkConnectionPriorityWireless% = int(val(networkConnectionPriorityWireless$))
			nc = CreateObject("roNetworkConfiguration", 1)
			if type(nc) = "roNetworkConfiguration" then
				nc.SetRoutingMetric(networkConnectionPriorityWireless%)
				nc.Apply()
				nc = invalid
			endif
		endif

' Retrieve data xfers enabled information from the sync spec and write to registry if it's changed
		m.bsp.contentXfersEnabledWired = GetDataTransferEnabled(m.statemachine.newSync, "contentXfersEnabledWired")
		m.bsp.registrySettings.contentXfersEnabledWired$ = m.UpdateRegistrySetting(m.stateMachine.newSync.LookupMetadata("client", "contentXfersEnabledWired"), m.bsp.registrySettings.contentXfersEnabledWired$, "cwr")

		m.bsp.textFeedsXfersEnabledWired = GetDataTransferEnabled(m.statemachine.newSync, "textFeedsXfersEnabledWired")
		m.bsp.registrySettings.textFeedsXfersEnabledWired$ = m.UpdateRegistrySetting(m.stateMachine.newSync.LookupMetadata("client", "textFeedsXfersEnabledWired"), m.bsp.registrySettings.textFeedsXfersEnabledWired$, "twr")

		m.bsp.healthXfersEnabledWired = GetDataTransferEnabled(m.statemachine.newSync, "healthXfersEnabledWired")
		m.bsp.registrySettings.healthXfersEnabledWired$ = m.UpdateRegistrySetting(m.stateMachine.newSync.LookupMetadata("client", "healthXfersEnabledWired"), m.bsp.registrySettings.healthXfersEnabledWired$, "hwr")

		m.bsp.mediaFeedsXfersEnabledWired = GetDataTransferEnabled(m.statemachine.newSync, "mediaFeedsXfersEnabledWired")
		m.bsp.registrySettings.mediaFeedsXfersEnabledWired$ = m.UpdateRegistrySetting(m.stateMachine.newSync.LookupMetadata("client", "mediaFeedsXfersEnabledWired"), m.bsp.registrySettings.mediaFeedsXfersEnabledWired$, "mwr")

		m.bsp.logUploadsXfersEnabledWired = GetDataTransferEnabled(m.statemachine.newSync, "logUploadsXfersEnabledWired")
		m.bsp.registrySettings.logUploadsXfersEnabledWired$ = m.UpdateRegistrySetting(m.stateMachine.newSync.LookupMetadata("client", "logUploadsXfersEnabledWired"), m.bsp.registrySettings.logUploadsXfersEnabledWired$, "lwr")
    
		m.bsp.contentXfersEnabledWireless = GetDataTransferEnabled(m.statemachine.newSync, "contentXfersEnabledWireless")
		m.bsp.registrySettings.contentXfersEnabledWireless$ = m.UpdateRegistrySetting(m.stateMachine.newSync.LookupMetadata("client", "contentXfersEnabledWireless"), m.bsp.registrySettings.contentXfersEnabledWireless$, "cwf")

		m.bsp.textFeedsXfersEnabledWireless = GetDataTransferEnabled(m.statemachine.newSync, "textFeedsXfersEnabledWireless")
		m.bsp.registrySettings.textFeedsXfersEnabledWireless$ = m.UpdateRegistrySetting(m.stateMachine.newSync.LookupMetadata("client", "textFeedsXfersEnabledWireless"), m.bsp.registrySettings.textFeedsXfersEnabledWireless$, "twf")

		m.bsp.healthXfersEnabledWireless = GetDataTransferEnabled(m.statemachine.newSync, "healthXfersEnabledWireless")
		m.bsp.registrySettings.healthXfersEnabledWireless$ = m.UpdateRegistrySetting(m.stateMachine.newSync.LookupMetadata("client", "healthXfersEnabledWireless"), m.bsp.registrySettings.healthXfersEnabledWireless$, "hwf")

		m.bsp.mediaFeedsXfersEnabledWireless = GetDataTransferEnabled(m.statemachine.newSync, "mediaFeedsXfersEnabledWireless")
		m.bsp.registrySettings.mediaFeedsXfersEnabledWireless$ = m.UpdateRegistrySetting(m.stateMachine.newSync.LookupMetadata("client", "mediaFeedsXfersEnabledWireless"), m.bsp.registrySettings.mediaFeedsXfersEnabledWireless$, "mwf")

		m.bsp.logUploadsXfersEnabledWireless = GetDataTransferEnabled(m.statemachine.newSync, "logUploadsXfersEnabledWireless")
		m.bsp.registrySettings.logUploadsXfersEnabledWireless$ = m.UpdateRegistrySetting(m.stateMachine.newSync.LookupMetadata("client", "logUploadsXfersEnabledWireless"), m.bsp.registrySettings.logUploadsXfersEnabledWireless$, "lwf")
    
' Retrieve logging information from the sync spec
        playbackLoggingEnabled = false
        b$ = LCase(m.statemachine.newSync.LookupMetadata("client", "playbackLoggingEnabled"))
        if b$ = "yes" then playbackLoggingEnabled = true

        eventLoggingEnabled = false
        b$ = LCase(m.statemachine.newSync.LookupMetadata("client", "eventLoggingEnabled"))
        if b$ = "yes" then eventLoggingEnabled = true

        diagnosticLoggingEnabled = false
        b$ = LCase(m.statemachine.newSync.LookupMetadata("client", "diagnosticLoggingEnabled"))
        if b$ = "yes" then diagnosticLoggingEnabled = true

        stateLoggingEnabled = false
        b$ = LCase(m.statemachine.newSync.LookupMetadata("client", "stateLoggingEnabled"))
        if b$ = "yes" then stateLoggingEnabled = true

        uploadLogFilesAtBoot = false
        b$ = LCase(m.statemachine.newSync.LookupMetadata("client", "uploadLogFilesAtBoot"))
        if b$ = "yes" then uploadLogFilesAtBoot = true

        uploadLogFilesAtSpecificTime = false
        b$ = LCase(m.statemachine.newSync.LookupMetadata("client", "uploadLogFilesAtSpecificTime"))
        if b$ = "yes" then uploadLogFilesAtSpecificTime = true

        uploadLogFilesTime% = 0
        uploadLogFilesTime$ = m.statemachine.newSync.LookupMetadata("client", "uploadLogFilesTime")
        if uploadLogFilesTime$ <> "" then uploadLogFilesTime% = int(val(uploadLogFilesTime$))
        
        m.stateMachine.logging.ReinitializeLogging(playbackLoggingEnabled, eventLoggingEnabled, stateLoggingEnabled, diagnosticLoggingEnabled, uploadLogFilesAtBoot, uploadLogFilesAtSpecificTime, uploadLogFilesTime%)

' Retrieve unit name, description from sync spec and write to registry if it's changed

        unitNameFromRegistry$ = m.bsp.registrySettings.unitName$
        unitNamingMethodFromRegistry$ = m.bsp.registrySettings.unitNamingMethod$
        unitDescriptionFromRegistry$ = m.bsp.registrySettings.unitDescription$

        unitName$ = m.stateMachine.newSync.LookupMetadata("client", "unitName")
        unitNamingMethod$ = m.stateMachine.newSync.LookupMetadata("client", "unitNamingMethod")
        unitDescription$ = m.stateMachine.newSync.LookupMetadata("client", "unitDescription")

        if unitName$ <> unitNameFromRegistry$ then
			m.bsp.WriteRegistrySetting("un", unitName$)
			m.bsp.registrySettings.unitName$ = unitName$
		endif
		
        if unitNamingMethod$ <> unitNamingMethodFromRegistry$ then
			m.bsp.WriteRegistrySetting("unm", unitNamingMethod$)
			m.bsp.registrySettings.unitNamingMethod$ = unitNamingMethod$
		endif
		
        if unitDescription$ <> unitDescriptionFromRegistry$ then
			m.bsp.WriteRegistrySetting("ud", unitDescription$)
			m.bsp.registrySettings.unitDescription$ = unitDescription$
		endif
                
' Retrieve latest network configuration information from sync spec
        useWireless$ = m.stateMachine.newSync.LookupMetadata("client", "useWireless")
        if not m.stateMachine.modelSupportsWifi then useWireless$ = "no"
        
        if useWireless$ = "yes" then
			m.stateMachine.useWireless = true
            ssid$ = m.stateMachine.newSync.LookupMetadata("client", "ssid")
            passphrase$ = m.stateMachine.newSync.LookupMetadata("client", "passphrase")
        else
			m.stateMachine.useWireless = false
		endif

        timeServer$ = m.stateMachine.newSync.LookupMetadata("client", "timeServer")

' if useDHCP is not set, don't touch the networking configuration (likely that the BrightSign is using simple networking)
        useDHCP = m.stateMachine.newSync.LookupMetadata("client", "useDHCP")
		if useDHCP <> "" then

			wiredNetworkingParameters = {}
			wiredNetworkingParameters.networkConfigurationIndex% = 0
			wiredNetworkingParameters.networkConnectionPriority$ = m.stateMachine.newSync.LookupMetadata("client", "networkConnectionPriorityWired")

			if m.stateMachine.useWireless then

				wirelessNetworkingParameters = {}
				wirelessNetworkingParameters.networkConfigurationIndex% = 1
				wirelessNetworkingParameters.networkConnectionPriority$ = m.stateMachine.newSync.LookupMetadata("client", "networkConnectionPriorityWireless")

				if useDHCP <> "" then
					wirelessNetworkingParameters.useDHCP$ = m.stateMachine.newSync.LookupMetadata("client", "useDHCP")
					if useDHCP = "no" then
						wirelessNetworkingParameters.staticIPAddress$ = m.stateMachine.newSync.LookupMetadata("client", "staticIPAddress")
						wirelessNetworkingParameters.subnetMask$ = m.stateMachine.newSync.LookupMetadata("client", "subnetMask")
						wirelessNetworkingParameters.gateway$ = m.stateMachine.newSync.LookupMetadata("client", "gateway")
						wirelessNetworkingParameters.dns1$ = m.stateMachine.newSync.LookupMetadata("client", "dns1")
						wirelessNetworkingParameters.dns2$ = m.stateMachine.newSync.LookupMetadata("client", "dns2")
						wirelessNetworkingParameters.dns3$ = m.stateMachine.newSync.LookupMetadata("client", "dns3")
					endif
					wirelessNetworkingParameters.useWireless = true
					wirelessNetworkingParameters.ssid$ = ssid$
					wirelessNetworkingParameters.passphrase$ = passphrase$
					wirelessNetworkingParameters.timeServer$ = timeServer$

					m.ConfigureNetwork(wirelessNetworkingParameters, m.bsp.registrySettings.wirelessNetworkingParameters, "")
				endif

				wiredNetworkingParameters.useDHCP$ = m.stateMachine.newSync.LookupMetadata("client", "useDHCP_2")
				if wiredNetworkingParameters.useDHCP$ = "no" then
					wiredNetworkingParameters.staticIPAddress$ = m.stateMachine.newSync.LookupMetadata("client", "staticIPAddress_2")
					wiredNetworkingParameters.subnetMask$ = m.stateMachine.newSync.LookupMetadata("client", "subnetMask_2")
					wiredNetworkingParameters.gateway$ = m.stateMachine.newSync.LookupMetadata("client", "gateway_2")
					wiredNetworkingParameters.dns1$ = m.stateMachine.newSync.LookupMetadata("client", "dns1_2")
					wiredNetworkingParameters.dns2$ = m.stateMachine.newSync.LookupMetadata("client", "dns2_2")
					wiredNetworkingParameters.dns3$ = m.stateMachine.newSync.LookupMetadata("client", "dns3_2")
				endif
				wiredNetworkingParameters.useWireless = false
				wiredNetworkingParameters.timeServer$ = timeServer$

				m.ConfigureNetwork(wiredNetworkingParameters, m.bsp.registrySettings.wiredNetworkingParameters, "2")

			else

				wiredNetworkingParameters.useDHCP$ = m.stateMachine.newSync.LookupMetadata("client", "useDHCP")
				if wiredNetworkingParameters.useDHCP$ = "no" then
					wiredNetworkingParameters.staticIPAddress$ = m.stateMachine.newSync.LookupMetadata("client", "staticIPAddress")
					wiredNetworkingParameters.subnetMask$ = m.stateMachine.newSync.LookupMetadata("client", "subnetMask")
					wiredNetworkingParameters.gateway$ = m.stateMachine.newSync.LookupMetadata("client", "gateway")
					wiredNetworkingParameters.dns1$ = m.stateMachine.newSync.LookupMetadata("client", "dns1")
					wiredNetworkingParameters.dns2$ = m.stateMachine.newSync.LookupMetadata("client", "dns2")
					wiredNetworkingParameters.dns3$ = m.stateMachine.newSync.LookupMetadata("client", "dns3")
				endif
				wiredNetworkingParameters.useWireless = false
				wiredNetworkingParameters.timeServer$ = timeServer$

				m.ConfigureNetwork(wiredNetworkingParameters, m.bsp.registrySettings.wiredNetworkingParameters, "")

				' if a device is setup to not use wireless, ensure that wireless is not used
				if m.stateMachine.modelSupportsWifi then
					nc = CreateObject("roNetworkConfiguration", 1)
					if type(nc) = "roNetworkConfiguration" then
						nc.SetDHCP()
						nc.SetWiFiESSID("")
						nc.SetObfuscatedWifiPassphrase("")
						nc.Apply()
					endif
				endif

			endif

		endif

		useWirelessFromRegistry$ = m.bsp.registrySettings.useWireless$
		ssidFromRegistry$ = m.bsp.registrySettings.ssid$
		passphraseFromRegistry$ = m.bsp.registrySettings.passphrase$
                    
        if useWirelessFromRegistry$ <> useWireless$ then 
			m.bsp.WriteRegistrySetting("wifi", useWireless$)
			m.bsp.registrySettings.useWireless$ = useWireless$
		endif
					
        if m.stateMachine.useWireless then
            if ssidFromRegistry$ <> ssid$ then 
				m.bsp.WriteRegistrySetting("ss", ssid$)
				m.bsp.registrySettings.ssid$ = ssid$
			endif
						
            if passphraseFromRegistry$ <> passphrase$ then
				m.bsp.WriteRegistrySetting("pp", passphrase$)
				m.bsp.registrySettings.passphrase$ = passphrase$
			endif
        endif
                    
        timeServerFromRegistry$ = m.bsp.registrySettings.timeServer$
        if timeServerFromRegistry$ <> timeServer$ then 
			m.bsp.WriteRegistrySetting("ts", timeServer$)
			m.bsp.registrySettings.timeServer$ = timeServer$
		endif

' Retrieve latest net connect spec information from sync spec
        timeBetweenHeartbeats$ = m.stateMachine.newSync.LookupMetadata("client", "timeBetweenHeartbeats")
		if timeBetweenHeartbeats$ <> "" then
			m.stateMachine.timeBetweenHeartbeats% = int(val(timeBetweenHeartbeats$))
		endif

        timeBetweenNetConnects$ = m.stateMachine.newSync.LookupMetadata("client", "timeBetweenNetConnects")
        
        if timeBetweenNetConnects$ <> "" then
        
			' check for timeBetweenNetConnects override
			tbnco$ = m.bsp.registrySettings.tbnco$
			if tbnco$ <> "" then
				timeBetweenNetConnects$	= tbnco$
			endif    

            ' if the timeBetweenNetConnects has changed, restart the timer
            newTimeBetweenNetConnects% = val(timeBetweenNetConnects$)
            if newTimeBetweenNetConnects% <> m.stateMachine.timeBetweenNetConnects% then
                m.stateMachine.timeBetweenNetConnects% = newTimeBetweenNetConnects%
                m.bsp.diagnostics.PrintDebug("### Time between net connects has changed to: " + timeBetweenNetConnects$)
            else
                m.bsp.diagnostics.PrintDebug("### Time between net connects = " + timeBetweenNetConnects$)
            endif
            
        endif
        
		' clear any existing timers associated with rate limitings / content download window
        if type(m.stateMachine.contentDownloadWindowStartTimer) = "roTimer" then
			m.stateMachine.contentDownloadWindowStartTimer.Stop()
		endif
        if type(m.stateMachine.contentDownloadWindowEndTimer) = "roTimer" then
			m.stateMachine.contentDownloadWindowEndTimer.Stop()
		endif

		' clear any existing timers associated with heartbeats window
        if type(m.stateMachine.heartbeatsWindowStartTimer) = "roTimer" then
			m.stateMachine.heartbeatsWindowStartTimer.Stop()
		endif
        if type(m.stateMachine.heartbeatsWindowEndTimer) = "roTimer" then
			m.stateMachine.heartbeatsWindowEndTimer.Stop()
		endif

		if m.stateMachine.useWireless then
			rateLimitModeOutsideWindowWired$ = m.stateMachine.newSync.LookupMetadata("client", "rateLimitModeOutsideWindow_2")
			rateLimitRateOutsideWindowWired$ = m.stateMachine.newSync.LookupMetadata("client", "rateLimitRateOutsideWindow_2")
			rateLimitModeInWindowWired$ = m.stateMachine.newSync.LookupMetadata("client", "rateLimitModeInWindow_2")
			rateLimitRateInWindowWired$ = m.stateMachine.newSync.LookupMetadata("client", "rateLimitRateInWindow_2")
		else
			rateLimitModeOutsideWindowWired$ = m.stateMachine.newSync.LookupMetadata("client", "rateLimitModeOutsideWindow")
			rateLimitRateOutsideWindowWired$ = m.stateMachine.newSync.LookupMetadata("client", "rateLimitRateOutsideWindow")
			rateLimitModeInWindowWired$ = m.stateMachine.newSync.LookupMetadata("client", "rateLimitModeInWindow")
			rateLimitRateInWindowWired$ = m.stateMachine.newSync.LookupMetadata("client", "rateLimitRateInWindow")
		endif
		' needs to also work in the SFN case where the values don't exist in the sync spec (same for contentDownloadsRestricted)
		' update rate limiting values
		SetRateLimitValues(false, m.stateMachine.wiredRateLimits, rateLimitModeOutsideWindowWired$, rateLimitRateOutsideWindowWired$, rateLimitModeInWindowWired$, rateLimitRateInWindowWired$)

		if m.stateMachine.useWireless then
			rateLimitModeOutsideWindowWireless$ = m.stateMachine.newSync.LookupMetadata("client", "rateLimitModeOutsideWindow")
			rateLimitRateOutsideWindowWireless$ = m.stateMachine.newSync.LookupMetadata("client", "rateLimitRateOutsideWindow")
			rateLimitModeInWindowWireless$ = m.stateMachine.newSync.LookupMetadata("client", "rateLimitModeInWindow")
			rateLimitRateInWindowWireless$ = m.stateMachine.newSync.LookupMetadata("client", "rateLimitRateInWindow")
		else
			rateLimitModeOutsideWindowWireless$ = m.stateMachine.newSync.LookupMetadata("client", "rateLimitModeOutsideWindow_2")
			rateLimitRateOutsideWindowWireless$ = m.stateMachine.newSync.LookupMetadata("client", "rateLimitRateOutsideWindow_2")
			rateLimitModeInWindowWireless$ = m.stateMachine.newSync.LookupMetadata("client", "rateLimitModeInWindow_2")
			rateLimitRateInWindowWireless$ = m.stateMachine.newSync.LookupMetadata("client", "rateLimitRateInWindow_2")
		endif
		' needs to also work in the SFN case where the values don't exist in the sync spec (same for contentDownloadsRestricted)
		' update rate limiting values
		SetRateLimitValues(false, m.stateMachine.wirelessRateLimits, rateLimitModeOutsideWindowWireless$, rateLimitRateOutsideWindowWireless$, rateLimitModeInWindowWireless$, rateLimitRateInWindowWireless$)

        currentTime = m.stateMachine.systemTime.GetLocalDateTime()

		heartbeatsRestricted = m.stateMachine.newSync.LookupMetadata("client", "heartbeatsRestricted")
        if heartbeatsRestricted = "yes" then
			m.stateMachine.heartbeatsRestricted = true
			heartbeatsRangeStart = m.stateMachine.newSync.LookupMetadata("client", "heartbeatsRangeStart")
			heartbeatsRangeLength = m.stateMachine.newSync.LookupMetadata("client", "heartbeatsRangeLength")
	        m.stateMachine.heartbeatsRangeStart% = val(heartbeatsRangeStart)
		    m.stateMachine.heartbeatsRangeLength% = val(heartbeatsRangeLength)

			startOfRange% = m.stateMachine.heartbeatsRangeStart%
			endOfRange% = startOfRange% + m.stateMachine.heartbeatsRangeLength%
            
			notInHeartbeatWindow = OutOfDownloadWindow(currentTime, startOfRange%, endOfRange%)

			if notInHeartbeatWindow then
				m.stateMachine.RestartHeartbeatsWindowStartTimer(currentTime, startOfRange%)
			else
				m.stateMachine.RestartHeartbeatsWindowEndTimer(currentTime, endOfRange%)
			endif
		else
			m.bsp.diagnostics.PrintDebug("### Heartbeats are unrestricted")
			m.stateMachine.heartbeatsRestricted = false
		endif

        contentDownloadsRestricted = m.stateMachine.newSync.LookupMetadata("client", "contentDownloadsRestricted")
        if contentDownloadsRestricted = "yes" then
            m.stateMachine.contentDownloadsRestricted = true
            contentDownloadRangeStart = m.stateMachine.newSync.LookupMetadata("client", "contentDownloadRangeStart")
            m.stateMachine.contentDownloadRangeStart% = val(contentDownloadRangeStart)
            contentDownloadRangeLength = m.stateMachine.newSync.LookupMetadata("client", "contentDownloadRangeLength")
            m.stateMachine.contentDownloadRangeLength% = val(contentDownloadRangeLength)
            m.bsp.diagnostics.PrintDebug("### Content downloads are restricted to the time from " + contentDownloadRangeStart + " for " + contentDownloadRangeLength + " minutes.")
        else
            m.bsp.diagnostics.PrintDebug("### Content downloads are unrestricted")
            m.stateMachine.contentDownloadsRestricted = false
        endif
                
' Only proceed with sync list download if the current time is within the range of allowed times for content downloads
        if m.stateMachine.contentDownloadsRestricted then
            startOfRange% = m.stateMachine.contentDownloadRangeStart%
            endOfRange% = startOfRange% + m.stateMachine.contentDownloadRangeLength%
            
			notInDownloadWindow = OutOfDownloadWindow(currentTime, startOfRange%, endOfRange%)

			if notInDownloadWindow then
				m.bsp.diagnostics.PrintDebug("### Not in window to download content")
	            m.stateMachine.AddDeviceDownloadItem("SyncSpecUnchanged", "", "")
			    m.stateMachine.numRetries% = 0
			    m.stateMachine.currentTimeBetweenNetConnects% = m.stateMachine.timeBetweenNetConnects%

				' if necessary, upload the list of current files to the server
				if m.stateMachine.FileListPendingUpload then
					m.stateMachine.BuildFileDownloadList(m.stateMachine.currentSync)
					m.stateMachine.UploadDeviceDownloadProgressFileList()
					m.stateMachine.FileListPendingUpload = false
				endif

	            m.stateMachine.newSync = invalid

				' set timer to go off when download window starts and program rate limit appropriately
				m.stateMachine.contentDownloadWindowStartTimer = CreateObject("roTimer")

				hour% = startOfRange% / 60
				minute% = startOfRange% - (hour% * 60)
				timeoutTime = CopyDateTime(currentTime)
				timeoutTime.SetHour(hour%)
				timeoutTime.SetMinute(minute%)
				timeoutTime.SetSecond(0)
				timeoutTime.SetMillisecond(0)
				GetNextTimeout(m.stateMachine.systemTime, timeoutTime)
				m.stateMachine.contentDownloadWindowStartTimer.SetDateTime(timeoutTime)
				m.stateMachine.contentDownloadWindowStartTimer.SetPort(m.stateMachine.msgPort)
				m.stateMachine.contentDownloadWindowStartTimer.Start()

		        m.bsp.diagnostics.PrintDebug("SyncSpecXferEvent: set timer to start of content download window" + timeoutTime.GetString())

				SetDownloadRateLimit(m.bsp.diagnostics, 0, m.stateMachine.wiredRateLimits.rlOutsideWindow%)

		        if m.stateMachine.useWireless then
					SetDownloadRateLimit(m.bsp.diagnostics, 1, m.stateMachine.wirelessRateLimits.rlOutsideWindow%)
				endif

				return m.stateMachine.stWaitForTimeout
			
			else
				' set timer to go off when download window ends and program rate limit appropriately
				m.stateMachine.contentDownloadWindowEndTimer = CreateObject("roTimer")
				currentTime.SetHour(0)
				currentTime.SetMinute(0)
				currentTime.SetSecond(0)
				currentTime.SetMillisecond(0)
				currentTime.AddSeconds(endOfRange% * 60)
				currentTime.Normalize()
				GetNextTimeout(m.stateMachine.systemTime, currentTime)
				m.stateMachine.contentDownloadWindowEndTimer.SetDateTime(currentTime)
				m.stateMachine.contentDownloadWindowEndTimer.SetPort(m.stateMachine.msgPort)
				m.stateMachine.contentDownloadWindowEndTimer.Start()

		        m.bsp.diagnostics.PrintDebug("STNetworkSchedulerEventHandler: set timer to end of content download window - " + currentTime.GetString())

				SetDownloadRateLimit(m.bsp.diagnostics, 0, m.stateMachine.wiredRateLimits.rlInWindow%)

		        if m.stateMachine.useWireless then
					SetDownloadRateLimit(m.bsp.diagnostics, 1, m.stateMachine.wirelessRateLimits.rlInWindow%)
				endif

			endif

        else

			SetDownloadRateLimit(m.bsp.diagnostics, 0, m.stateMachine.wiredRateLimits.rlOutsideWindow%)

	        if m.stateMachine.useWireless then
				SetDownloadRateLimit(m.bsp.diagnostics, 1, m.stateMachine.wirelessRateLimits.rlOutsideWindow%)
			endif

		endif
	
        return m.stateMachine.stDownloadingSyncFiles
	
    else if event.GetResponseCode() = 404 then
    
        m.bsp.diagnostics.PrintDebug("### Server has no sync list for us: 404")
        m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_NO_SYNCSPEC_AVAILABLE, "404")
    
    else
		' retry - server returned something other than a 200 or 404
		m.stateMachine.ResetDownloadTimerToDoRetry()
        m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_RETRIEVE_SYNCSPEC_FAILURE, str(event.GetResponseCode()))
        m.bsp.diagnostics.PrintDebug("### Failed to download sync list: " + str(event.GetResponseCode()))
        m.stateMachine.AddDeviceErrorItem("deviceError", "", "Failed to download sync list", str(event.GetResponseCode()))
        
	endif

	return m.stateMachine.stWaitForTimeout
	
End Function


Sub SetDownloadRateLimit(diagnostics As Object, networkConfigurationIndex% As Integer, rateLimit% As Integer)
	nc = CreateObject("roNetworkConfiguration", networkConfigurationIndex%)
	if type(nc) = "roNetworkConfiguration"
		diagnostics.PrintDebug("SetInboundShaperRate to " + stri(rateLimit%))
		ok = nc.SetInboundShaperRate(rateLimit%)
		if not ok then print "Failure calling SetInboundShaperRate with parameter ";rateLimit%
		ok = nc.Apply()
		if not ok then print "Failure calling roNetworkConfiguration.Apply()"
	endif
End Sub


Function UpdateRegistrySetting(newValue$ As String, existingValue$ As String, registryKey$ As String) As String

	if lcase(newValue$) <> lcase(existingValue$) then
		m.bsp.WriteRegistrySetting(registryKey$, newValue$)
	endif

	return newValue$

End Function


Sub ConfigureNetwork(networkingParameters As Object, registryNetworkingParameters As Object, registryKeySuffix$ As String)

    nc = CreateObject("roNetworkConfiguration", networkingParameters.networkConfigurationIndex%)
    if type(nc) = "roNetworkConfiguration" then
        if networkingParameters.useDHCP$ = "no" then
                
            nc.SetIP4Address(networkingParameters.staticIPAddress$)
            nc.SetIP4Netmask(networkingParameters.subnetMask$)
'            nc.SetIP4Broadcast(networkingParameters.broadcast$)
            nc.SetIP4Gateway(networkingParameters.gateway$)
            if networkingParameters.dns1$ <> "" then nc.AddDNSServer(networkingParameters.dns1$)
            if networkingParameters.dns2$ <> "" then nc.AddDNSServer(networkingParameters.dns2$)
            if networkingParameters.dns3$ <> "" then nc.AddDNSServer(networkingParameters.dns3$)
                    
        else
                
            nc.SetDHCP()
                
        endif

		nc.SetRoutingMetric(int(val(networkingParameters.networkConnectionPriority$)))

        if networkingParameters.useWireless then
            nc.SetWiFiESSID(networkingParameters.ssid$)
            nc.SetObfuscatedWifiPassphrase(networkingParameters.passphrase$)
        endif

        timeServer$ = m.stateMachine.newSync.LookupMetadata("client", "timeServer")
        nc.SetTimeServer(networkingParameters.timeServer$)
        success = nc.Apply()
        nc = invalid

        if not success then
            m.bsp.diagnostics.PrintDebug("### roNetworkConfiguration.Apply failure.")
        else
            ' save parameters to the registry
			networkConnectionPriorityFromRegistry$ = registryNetworkingParameters.networkConnectionPriority$
            if networkConnectionPriorityFromRegistry$ <> networkingParameters.networkConnectionPriority$ then
				m.bsp.WriteRegistrySetting("ncp" + registryKeySuffix$, networkingParameters.networkConnectionPriority$)
				registryNetworkingParameters.networkConnectionPriority$ = networkingParameters.networkConnectionPriority$
			endif

            if networkingParameters.useDHCP$ = "no" then
                    
				if registryNetworkingParameters.useDHCP$ <> "no" then
					m.bsp.WriteRegistrySetting("dhcp" + registryKeySuffix$, "no")
					registryNetworkingParameters.useDHCP$ = "no"
                endif
                        
                staticIPAddressFromRegistry$ = registryNetworkingParameters.staticIPAddress$
                subnetMaskFromRegistry$ = registryNetworkingParameters.subnetMask$
                gatewayFromRegistry$ = registryNetworkingParameters.gateway$
'                broadcastFromRegistry$ = registryNetworkingParameters.broadcast$
                dns1FromRegistry$ = registryNetworkingParameters.dns1$
                dns2FromRegistry$ = registryNetworkingParameters.dns2$
                dns3FromRegistry$ = registryNetworkingParameters.dns3$

                if staticIPAddressFromRegistry$ <> networkingParameters.staticIPAddress$ then
					m.bsp.WriteRegistrySetting("sip" + registryKeySuffix$, networkingParameters.staticIPAddress$)
					registryNetworkingParameters.staticIPAddress$ = networkingParameters.staticIPAddress$
				endif
						
                if subnetMaskFromRegistry$ <> networkingParameters.subnetMask$ then 
					m.bsp.WriteRegistrySetting("sm" + registryKeySuffix$, networkingParameters.subnetMask$)
					registryNetworkingParameters.subnetMask$ = networkingParameters.subnetMask$
				endif
						
                if gatewayFromRegistry$ <> networkingParameters.gateway$ then 
					m.bsp.WriteRegistrySetting("gw" + registryKeySuffix$, networkingParameters.gateway$)
					registryNetworkingParameters.gateway$ = networkingParameters.gateway$
				endif
						
                if dns1FromRegistry$ <> networkingParameters.dns1$ then 
					m.bsp.WriteRegistrySetting("d1" + registryKeySuffix$, networkingParameters.dns1$)
					registryNetworkingParameters.dns1$ = networkingParameters.dns1$
				endif
						
                if dns2FromRegistry$ <> networkingParameters.dns2$ then 
					m.bsp.WriteRegistrySetting("d2" + registryKeySuffix$, networkingParameters.dns2$)
					registryNetworkingParameters.dns2$ = networkingParameters.dns2$
				endif
						
                if dns3FromRegistry$ <> networkingParameters.dns3$ then 
					m.bsp.WriteRegistrySetting("d3" + registryKeySuffix$, networkingParameters.dns3$)
					registryNetworkingParameters.dns3$ = networkingParameters.dns3$
				endif
                    
            else
                    
				if registryNetworkingParameters.useDHCP$ <> "yes" then
					m.bsp.WriteRegistrySetting("dhcp" + registryKeySuffix$, "yes")
					registryNetworkingParameters.useDHCP$ = "yes"
				endif
						
            endif

        endif

    else

        m.bsp.diagnostics.PrintDebug("Unable to create roNetworkConfiguration - index = " + stri(networkConfigurationIndex%))
	
	endif

End Sub


Function STDownloadingSyncFilesEventHandler(event As Object, stateData As Object) As Object

    stateData.nextState = invalid
    
    if type(event) = "roAssociativeArray" then      ' internal message event

        if IsString(event["EventType"]) then
        
            if event["EventType"] = "ENTRY_SIGNAL" then
            
                m.bsp.diagnostics.PrintDebug(m.id$ + ": entry signal")

                nextState = m.StartSyncListDownload()
                                
                if type(nextState) = "roAssociativeArray" then
                    stop ' can't do this - no transitions on entry
'!!!!!!!!!!!!!!!!!! - is this a violation? performing a transition on an entry signal?                
                    stateData.nextState = nextState
		            return "TRANSITION"
                endif

                return "HANDLED"

            else if event["EventType"] = "EXIT_SIGNAL" then

                m.bsp.diagnostics.PrintDebug(m.id$ + ": exit signal")
            else if event["EventType"] = "CANCEL_DOWNLOADS" then
            
				m.bsp.diagnostics.PrintDebug("Cancel syncPool downloads message received")
				if type(m.stateMachine.syncPool) = "roSyncPool" then
					m.bsp.diagnostics.PrintDebug("Cancel syncPool downloads")
					m.stateMachine.syncPool.AsyncCancel()
					m.stateMachine.syncPool = invalid
					stateData.nextState = m.stateMachine.stWaitForTimeout
					return "TRANSITION"
				else
					return "HANDLED"
				endif
				
            endif
            
        endif
        
    else if type(event) = "roSyncPoolProgressEvent" then

		m.bsp.diagnostics.PrintDebug("### File download progress " + event.GetFileName() + str(event.GetCurrentFilePercentage()))

		m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_FILE_DOWNLOAD_PROGRESS, event.GetFileName() + chr(9) + str(event.GetCurrentFilePercentage()))

		fileIndex% = event.GetFileIndex()
		fileItem = m.stateMachine.newSync.GetFile("download", fileIndex%)
		m.stateMachine.AddDeviceDownloadProgressItem(fileItem, str(event.GetCurrentFilePercentage()), "ok")

        return "HANDLED"

    else if type(event) = "roSyncPoolEvent" then

	    if stri(event.GetSourceIdentity()) = stri(m.stateMachine.syncPool.GetIdentity()) then

	        nextState = m.HandleSyncPoolEvent(event)
	        
            if type(nextState) = "roAssociativeArray" then
                stateData.nextState = nextState
	            return "TRANSITION"
            endif

            return "HANDLED"
            
	    endif

    endif
            
    stateData.nextState = m.superState
    return "SUPER"
    
End Function


Function StartSyncListDownload() As Object

    m.bsp.diagnostics.PrintDebug("### Start sync list download")
    m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_DOWNLOAD_START, "")
    m.stateMachine.AddEventItem("StartSyncListDownload", m.stateMachine.newSync.GetName(), "")

    m.stateMachine.syncPool = CreateObject("roSyncPool", "pool")
	m.stateMachine.syncPool.ReserveMegabytes(50)
    m.stateMachine.syncPool.SetPort(m.stateMachine.msgPort)
    if m.stateMachine.setUserAndPassword then m.stateMachine.syncPool.SetUserAndPassword(m.stateMachine.user$, m.stateMachine.password$)
	m.stateMachine.syncPool.EnableUnsafeAuthentication(m.stateMachine.enableUnsafeAuthentication)
    m.stateMachine.syncPool.SetMinimumTransferRate(1000,900)
    m.stateMachine.syncPool.SetHeaders(m.stateMachine.newSync.GetMetadata("server"))
    m.stateMachine.syncPool.AddHeader("DeviceID", m.stateMachine.deviceUniqueID$)
    m.stateMachine.syncPool.AddHeader("DeviceModel", m.stateMachine.deviceModel$)
	m.stateMachine.syncPool.AddHeader("DeviceFamily", m.stateMachine.deviceFamily$)
    m.stateMachine.syncPool.SetFileProgressIntervalSeconds(15)

	binding% = GetBinding(m.stateMachine.bsp.contentXfersEnabledWired, m.stateMachine.bsp.contentXfersEnabledWireless)
    m.bsp.diagnostics.PrintDebug("### Binding for syncPool is " + stri(binding%))
	ok = m.stateMachine.syncPool.BindToInterface(binding%)
	if not ok then stop

' clear file download failure count                
	m.stateMachine.fileDownloadFailureCount% = 0
				
' this error implies that the current sync list is corrupt - go back to sync list in registry and reboot - no need to retry. do this by deleting autorun.brs and rebooting
    if not m.stateMachine.syncPool.ProtectFiles(m.stateMachine.currentSync, 0) then ' don't allow download to delete current files
		m.stateMachine.LogProtectFilesFailure()				
    endif
    
    if m.stateMachine.proxy_mode then
        m.stateMachine.syncPool.AddHeader("Roku-Cache-Request", "Yes")
    endif
    
    if m.stateMachine.syncType$ = "download" then
        if m.stateMachine.downloadOnlyIfCached then m.stateMachine.syncPool.AddHeader("Cache-Control", "only-if-cached")
        if not m.stateMachine.syncPool.AsyncDownload(m.stateMachine.newSync) then
            m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_SYNCSPEC_DOWNLOAD_IMMEDIATE_FAILURE, m.stateMachine.syncPool.GetFailureReason())
            m.bsp.diagnostics.PrintTimestamp()
            m.bsp.diagnostics.PrintDebug("### AsyncDownload failed: " + m.stateMachine.syncPool.GetFailureReason())
            m.stateMachine.AddDeviceErrorItem("deviceError", m.stateMachine.newSync.GetName(), "AsyncDownloadFailure: " + m.stateMachine.syncPool.GetFailureReason(), "")
            m.stateMachine.ResetDownloadTimerToDoRetry()
            m.stateMachine.newSync = invalid
			return m.stateMachine.stWaitForTimeout
        endif
    else
        m.stateMachine.syncPool.AsyncSuggestCache(m.stateMachine.newSync)
    endif
    
    return 0

End Function


Function HandleSyncPoolEvent(event As Object) As Object

    m.bsp.diagnostics.PrintTimestamp()
    m.bsp.diagnostics.PrintDebug("### pool_event")

	if (event.GetEvent() = m.stateMachine.POOL_EVENT_FILE_DOWNLOADED) then
        m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_FILE_DOWNLOAD_COMPLETE, event.GetName())
        m.bsp.diagnostics.PrintDebug("### File downloaded " + event.GetName())
        
        ' see if the user should be charged for this download
        if m.stateMachine.chargeableFiles.DoesExist(event.GetName()) then
            filePath$ = m.stateMachine.syncPoolFiles.GetPoolFilePath(event.GetName())            
            file = CreateObject("roReadFile", filePath$)
            if type(file) = "roReadFile" then
                file.SeekToEnd()

				totalContentDownloaded# = m.stateMachine.contentDownloaded#
		        totalContentDownloaded# = totalContentDownloaded# + file.CurrentPosition()
				m.stateMachine.contentDownloaded# = totalContentDownloaded#

                m.bsp.diagnostics.PrintDebug("### File size " + str(file.CurrentPosition()))
				m.bsp.diagnostics.PrintDebug("### Content downloaded = " + str(m.stateMachine.contentDownloaded#))
            endif
            file = invalid
        endif

	else if (event.GetEvent() = m.stateMachine.POOL_EVENT_FILE_FAILED) then
        m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_FILE_DOWNLOAD_FAILURE, event.GetName() + chr(9) + event.GetFailureReason())
        m.bsp.diagnostics.PrintDebug("### File failed " + event.GetName() + ": " + event.GetFailureReason())
        m.stateMachine.AddDeviceErrorItem("FileDownloadFailure", event.GetName(), event.GetFailureReason(), str(event.GetResponseCode()))
        
        ' log this error to the download progress handler
        fileIndex% = event.GetFileIndex()
        fileItem = m.stateMachine.newSync.GetFile("download", fileIndex%)
        if type(fileItem) = "roAssociativeArray" then
            m.stateMachine.AddDeviceDownloadProgressItem(fileItem, "-1", event.GetFailureReason())
        endif

		m.stateMachine.fileDownloadFailureCount% = m.stateMachine.fileDownloadFailureCount% + 1
		if m.stateMachine.fileDownloadFailureCount% >= m.stateMachine.maxFileDownloadFailures% then
            m.bsp.diagnostics.PrintDebug("### " + stri(m.stateMachine.maxFileDownloadFailures%) + " file download failures - set timer for retry.")
            m.stateMachine.syncPool.AsyncCancel()
		    m.stateMachine.ResetDownloadTimerToDoRetry()
			m.stateMachine.syncPool = invalid
	        return m.stateMachine.stWaitForTimeout
		endif
       
	else if (event.GetEvent() = m.stateMachine.POOL_EVENT_ALL_FAILED) then
	    if m.stateMachine.syncType$ = "download" then
		    m.stateMachine.ResetDownloadTimerToDoRetry()
            m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_SYNCSPEC_DOWNLOAD_FAILURE, event.GetFailureReason())		
            m.bsp.diagnostics.PrintDebug("### Sync failed: " + event.GetFailureReason())
            m.stateMachine.AddDeviceErrorItem("POOL_EVENT_ALL_FAILED", "", event.GetFailureReason(), str(event.GetResponseCode()))

            ' capture total content downloaded
            m.bsp.diagnostics.PrintDebug("### Total content downloaded = " + str(m.stateMachine.contentDownloaded#))
            ok = m.stateMachine.UploadTrafficDownload(m.stateMachine.contentDownloaded#)
            if ok then
				m.stateMachine.contentDownloaded# = 0
			endif
        else
            m.bsp.diagnostics.PrintDebug("### Proxy mode sync complete")
        endif
		m.stateMachine.newSync = invalid
		m.stateMachine.syncPool = invalid
    
        return m.stateMachine.stWaitForTimeout
    
	elseif (event.GetEvent() = m.stateMachine.POOL_EVENT_ALL_DOWNLOADED) then

        m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_DOWNLOAD_COMPLETE, "")		
        m.bsp.diagnostics.PrintDebug("### All files downloaded")
        m.stateMachine.AddDeviceDownloadItem("All files downloaded", "", "")

' send up the list of files downloaded
		m.stateMachine.BuildFileDownloadList(m.stateMachine.newSync)
        m.stateMachine.UploadDeviceDownloadProgressFileList()
		m.stateMachine.FileListPendingUpload = false

' capture total content downloaded
        m.bsp.diagnostics.PrintDebug("### Total content downloaded = " + str(m.stateMachine.contentDownloaded#))
        ok = m.stateMachine.UploadTrafficDownload(m.stateMachine.contentDownloaded#)
        if ok then
			m.stateMachine.contentDownloaded# = 0
		endif
        
' Log the end of sync list download
        m.stateMachine.AddEventItem("EndSyncListDownload", m.stateMachine.newSync.GetName(), str(event.GetResponseCode()))

' Clear retry count and reset timeout period
		m.stateMachine.numRetries% = 0
	    m.stateMachine.currentTimeBetweenNetConnects% = m.stateMachine.timeBetweenNetConnects%
    
' diagnostic web server
		dwsParams = GetDWSParams(m.stateMachine.newSync, m.bsp.registrySettings)

		dwsRebootRequired = false
		nc = CreateObject("roNetworkConfiguration", 0)
		if type(nc) = "roNetworkConfiguration"
			dwsAA = CreateObject("roAssociativeArray")
			if dwsParams.dwsEnabled$ = "yes" then
				dwsAA["port"] = "80"
				dwsAA["password"] = dwsParams.dwsPassword$
			endif
			dwsRebootRequired = nc.SetupDWS(dwsAA)
			nc = invalid
		endif
                
		oldSyncSpecScriptsOnly  = m.stateMachine.currentSync.FilterFiles("download", { group: "script" } )
		newSyncSpecScriptsOnly  = m.stateMachine.newSync.FilterFiles("download", { group: "script" } )
	
		rebootRequired = false

		if not oldSyncSpecScriptsOnly.FilesEqualTo(newSyncSpecScriptsOnly) then

			' Protect all the media files that the current sync spec is using in case we fail part way 
			' through and need to continue using it. 
			if not (m.stateMachine.syncPool.ProtectFiles(m.stateMachine.currentSync, 0) and m.stateMachine.syncPool.ProtectFiles(m.stateMachine.newSync, 0)) then
				m.stateMachine.LogProtectFilesFailure()				
			endif   

			event = m.stateMachine.syncPool.Realize(newSyncSpecScriptsOnly, "/")

			if event.GetEvent() <> m.stateMachine.EVENT_REALIZE_SUCCESS then
		        m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_REALIZE_FAILURE, stri(event.GetEvent()) + chr(9) + event.GetName() + chr(9) + event.GetFailureReason())
				m.bsp.diagnostics.PrintDebug("### Realize failed " + stri(event.GetEvent()) + chr(9) + event.GetName() + chr(9) + event.GetFailureReason() )
				m.stateMachine.AddDeviceErrorItem("RealizeFailure", event.GetName(), event.GetFailureReason(), str(event.GetEvent()))
			
				m.stateMachine.newSync = invalid
				m.stateMachine.syncPool = invalid
    
				return m.stateMachine.stWaitForTimeout
			endif

			' reboot if successful
			rebootRequired = true

		endif

' Save to current-sync.xml then do cleanup
	    if not m.stateMachine.newSync.WriteToFile("current-sync.xml") then stop
        timezone = m.stateMachine.newSync.LookupMetadata("client", "timezone")
        if timezone <> "" then
            m.stateMachine.systemTime.SetTimeZone(timezone)
        endif

        m.bsp.diagnostics.PrintTimestamp()
        m.bsp.diagnostics.PrintDebug("### DOWNLOAD COMPLETE")
        
        DeleteFile("bad-sync.xml")

		if rebootRequired then
			m.bsp.diagnostics.PrintDebug("### new script or upgrade found - reboot")
            m.stateMachine.AddEventItem("DownloadComplete - new script or upgrade file found", m.stateMachine.newSync.GetName(), "")
            m.stateMachine.RebootAfterEventsSent()
		endif

		if dwsRebootRequired then
            m.bsp.diagnostics.PrintDebug("### DWS parameter change - reboot")
            m.stateMachine.AddEventItem("DownloadComplete - DWS parameter change", m.stateMachine.newSync.GetName(), "")
            m.stateMachine.RebootAfterEventsSent()
		endif

        m.stateMachine.syncPoolFiles = CreateObject("roSyncPoolFiles", "pool", m.stateMachine.newSync)
        if type(m.stateMachine.syncPoolFiles) <> "roSyncPoolFiles" then stop
        
		globalAA = GetGlobalAA()
		globalAA.autoscheduleFilePath$ = GetPoolFilePath(m.stateMachine.syncPoolFiles, "autoschedule.xml")
		globalAA.resourcesFilePath$ = GetPoolFilePath(m.stateMachine.syncPoolFiles, "resources.txt")
		globalAA.boseProductsFilePath$ = GetPoolFilePath(m.stateMachine.syncPoolFiles, "BoseProducts.xml")
		if globalAA.autoscheduleFilePath$ = "" then stop

		m.stateMachine.newSync = invalid
		m.stateMachine.syncPool = invalid

        ' reset m.currentSync (could the script just do m.currentSync = m.newSync earlier?)
        
        m.stateMachine.currentSync = CreateObject("roSyncSpec")
        if type(m.stateMachine.currentSync) <> "roSyncSpec" then stop
        if not m.stateMachine.currentSync.ReadFromFile("current-sync.xml") then stop

        m.bsp.diagnostics.PrintTimestamp()
        m.bsp.diagnostics.PrintDebug("### return from HandleSyncPoolEvent")

		debugOn = false
		if m.stateMachine.currentSync.LookupMetadata("client", "enableSerialDebugging") = "True" then
			debugOn = true
		endif
		m.bsp.diagnostics.UpdateDebugOn(debugOn)

		systemLogDebugOn = false
		if m.stateMachine.currentSync.LookupMetadata("client", "enableSystemLogDebugging") = "True" then
			systemLogDebugOn = true
		endif
		m.bsp.diagnostics.UpdateSystemLogDebugOn(systemLogDebugOn)

' send internal message to prepare for restart
        prepareForRestartEvent = CreateObject("roAssociativeArray")
        prepareForRestartEvent["EventType"] = "PREPARE_FOR_RESTART"
        m.stateMachine.msgPort.PostMessage(prepareForRestartEvent)

' send internal message indicating that new content is available
        contentUpdatedEvent = CreateObject("roAssociativeArray")
        contentUpdatedEvent["EventType"] = "CONTENT_UPDATED"
        m.stateMachine.msgPort.PostMessage(contentUpdatedEvent)

        return m.stateMachine.stWaitForTimeout
            
    endif

	
End Function


Sub LogProtectFilesFailure()
	m.stateMachine.logging.WriteDiagnosticLogEntry(m.stateMachine.diagnosticCodes.EVENT_SYNCPOOL_PROTECT_FAILURE, m.stateMachine.syncPool.GetFailureReason())
	m.stateMachine.logging.FlushLogFile()
	DeleteFile("autorun.brs")
	m.bsp.diagnostics.PrintDebug("### ProtectFiles failed: " + m.stateMachine.syncPool.GetFailureReason())
	m.stateMachine.AddDeviceErrorItem("deviceError", m.stateMachine.currentSync.GetName(), "ProtectFilesFailure: " + m.stateMachine.syncPool.GetFailureReason(), "")
	msg = wait(10000, 0)   ' wait for either a timeout (10 seconds) or a message indicating that the post was complete
	a=RebootSystem()
End Sub

'endregion

'region BP State Machine
' *************************************************
'
' BP State Machine
'
' *************************************************
Function newBPStateMachine(bsp As Object, inputPortIdentity$ As String, buttonPanelIndex% As Integer, buttonNumber% As Integer) As Object

	BPStateMachine = CreateObject("roAssociativeArray")
	
	BPStateMachine.bsp = bsp
	BPStateMachine.msgPort = bsp.msgPort
	BPStateMachine.inputPortIdentity$ = inputPortIdentity$
	BPStateMachine.buttonPanelIndex% = buttonPanelIndex%
	BPStateMachine.buttonNumber% = buttonNumber%
	BPStateMachine.timer = invalid
	
	BPStateMachine.configuration$ = "press"
	BPStateMachine.initialHoldoff% = -1
	BPStateMachine.repeatInterval% = -1	
	
	BPStateMachine.ConfigureButton = ConfigureButton
	BPStateMachine.EventHandler = BPEventHandler
		
	BPStateMachine.state$ = "ButtonUp"

	return BPStateMachine
	
End Function


Sub BPEventHandler(event As Object)

	if m.state$ = "ButtonUp" then

		if type(event) = "roControlDown" and stri(event.GetSourceIdentity()) = m.inputPortIdentity$ and m.buttonNumber% = event.GetInt() then
    		
			m.bsp.diagnostics.PrintDebug("BP control down" + str(event.GetInt()))

			bpControlDown = CreateObject("roAssociativeArray")
			bpControlDown["EventType"] = "BPControlDown"
			bpControlDown["ButtonPanelIndex"] = StripLeadingSpaces(str(m.buttonPanelIndex%))
			bpControlDown["ButtonNumber"] = StripLeadingSpaces(str(event.GetInt()))
			m.msgPort.PostMessage(bpControlDown)

			if m.configuration$ = "pressContinuous" then
				m.timer = CreateObject("roTimer")
				m.timer.SetPort(m.msgPort)
				newTimeout = m.bsp.systemTime.GetLocalDateTime()
				newTimeout.AddMilliseconds(m.initialHoldoff%)
				m.timer.SetDateTime(newTimeout)
				m.timer.Start()
			endif
			
            m.state$ = "ButtonDown"
	
		endif
		
    else 
    
		if type(event) = "roControlUp" and stri(event.GetSourceIdentity()) = m.inputPortIdentity$ and m.buttonNumber% = event.GetInt() then
    
			m.bsp.diagnostics.PrintDebug("BP control up" + str(event.GetInt()))

			' if continuous, stop and destroy the timer
			if type(m.timer) = "roTimer" then
				m.timer.Stop()
				m.timer = invalid
			endif

            m.state$ = "ButtonUp"
			    
		' else check for repeat timeout
		else if type(event) = "roTimerEvent" and type(m.timer) = "roTimer" then
            if stri(event.GetSourceIdentity()) = stri(m.timer.GetIdentity()) then
            
				m.bsp.diagnostics.PrintDebug("BP REPEAT control down" + str(m.buttonNumber%))

				bpControlDown = CreateObject("roAssociativeArray")
				bpControlDown["EventType"] = "BPControlDown"
				bpControlDown["ButtonPanelIndex"] = StripLeadingSpaces(str(m.buttonPanelIndex%))
				bpControlDown["ButtonNumber"] = StripLeadingSpaces(str(m.buttonNumber%))
				m.msgPort.PostMessage(bpControlDown)

				newTimeout = m.bsp.systemTime.GetLocalDateTime()
				newTimeout.AddMilliseconds(m.repeatInterval%)
				m.timer.SetDateTime(newTimeout)
				m.timer.Start()
			
            endif
		endif
	endif
	
End Sub


Sub ConfigureButton(bpSpec As Object)

	bpConfiguration$ = bpSpec.configuration$
	
' no change necessary if the old and new configurations are the same and are a simple press	
	if bpConfiguration$ = "press" and m.configuration$ = "press" then return

' if the old configuration was continuous and the new configuration is a simple press, stop the timer and destroy the timer object	
	if bpConfiguration$ = "press" and m.configuration$ = "pressContinuous" then
		if type(m.timer) = "roTimer" then
			m.timer.Stop()
			m.timer = invalid
		endif
		m.configuration$ = "press"
		return
	endif
	
' capture the repeat rates if the new configuration is continuous	
	if bpConfiguration$ = "pressContinuous" then
		m.initialHoldoff% = int(val(bpSpec.initialHoldoff$))
		m.repeatInterval% = int(val(bpSpec.repeatInterval$))		
	endif	
	
' if both the old and new configurations are continuous, restart the timer (if it is active)
	if bpConfiguration$ = "pressContinuous" and m.configuration$ = "pressContinuous" then
		if type(m.timer) = "roTimer" then
			m.timer.Stop()
			newTimeout = m.bsp.systemTime.GetLocalDateTime()
			newTimeout.AddMilliseconds(m.initialHoldoff%)
			m.timer.SetDateTime(newTimeout)
			m.timer.Start()
		endif
	endif
	
' if the old configuration was simple press and the new configuration is continuous, then capture the new values
' but don't start a timer (repeating won't start if the button was down at the time the state is entered).
	m.configuration$ = bpConfiguration$
	
End Sub

'endregion

'region EventLoop
' *************************************************
'
' Event Loop and associated processing
'
' *************************************************
Sub EventLoop()

	SQLITE_COMPLETE = 100

    while true
        
        msg = wait(0, m.msgPort)
        
		m.diagnostics.PrintTimestamp()
		m.diagnostics.PrintDebug("msg received - type=" + type(msg))

	    if type(msg) = "roControlDown" and stri(msg.GetSourceIdentity()) = stri(m.controlPort.GetIdentity()) then
            if msg.GetInt()=12 then
                stop
            endif
        endif

		eventHandled = false
		for each scriptPlugin in m.scriptPlugins
'			ERR_NORMAL_END = &hFC
			eventHandled = scriptPlugin.plugin.ProcessEvent(msg)
			if eventHandled then
				exit for
			endif
'			retVal = Eval("eventHandled = scriptPlugin.plugin.ProcessEvent(msg)")
'			if retVal <> &hFC then
'				' log the failure
'				m.diagnostics.PrintDebug("Failure executing Eval to execute script plugin file event handler: return value = " + stri(retVal))
'				m.logging.WriteDiagnosticLogEntry(m.diagnosticCodes.EVENT_SCRIPT_PLUGIN_FAILURE, stri(retVal) + chr(9) + "EventHandler")
'			endif
		next

		' don't propagate the event if it was handled by a plugin
		if not eventHandled then

			if type(msg) = "roSqliteEvent" then
				if msg.GetSqlResult() <> SQLITE_COMPLETE then
					m.diagnostics.PrintDebug("roSqliteEvent.GetSqlResult() <> SQLITE_COMPLETE")
					if type(msg.GetSqlResult()) = "roInt" then
						m.diagnostics.PrintDebug("roSqliteEvent.GetSqlResult() = " + stri(roSqliteEvent.GetSqlResult()))
					endif
				endif
			endif

			if type(msg) = "roHttpEvent" then
        
				userdata = msg.GetUserData()
				if type(userdata) = "roAssociativeArray" and type(userdata.HandleEvent) = "roFunction" then
					userData.HandleEvent(userData, msg)
				endif

			else
		                                     
				m.playerHSM.Dispatch(msg)
			
				for buttonPanelIndex% = 0 to 2
					for i% = 0 to 10
						if type(m.bpSM[buttonPanelIndex%, i%]) = "roAssociativeArray" then
							m.bpSM[buttonPanelIndex%, i%].EventHandler(msg)
						endif
					next
				next

				if type(m.sign) = "roAssociativeArray" then

					numZones% = m.sign.zonesHSM.Count()
					for i% = 0 to numZones% - 1
						m.dispatchingZone = m.sign.zonesHSM[i%]
						m.dispatchingZone.Dispatch(msg)
					next

				endif

				if m.networkingActive then
					m.networkingHSM.Dispatch(msg)
				endif

			endif

		endif

    end while
    
End Sub


Function ExecuteSwitchPresentationCommand(presentationName$ As String) As Boolean

	' retrieve target presentation
	presentation = m.presentations.Lookup(presentationName$)

	if type(presentation) = "roAssociativeArray" then

		' check for existence of target presentation - if it's not present, don't try to switch to it
		autoplayFileName$ = "autoplay-" + presentation.presentationName$ + ".xml"
		xmlFileName$ = m.syncPoolFiles.GetPoolFilePath(autoplayFileName$)
		if xmlFileName$ = "" then
			m.diagnostics.PrintDebug("switchPresentation: target presentation not found - " + presentationName$)
			return false
		endif

		' send internal message to prepare for restart
		prepareForRestartEvent = CreateObject("roAssociativeArray")
		prepareForRestartEvent["EventType"] = "PREPARE_FOR_RESTART"
		m.msgPort.PostMessage(prepareForRestartEvent)

		' send switch presentation internal message
		switchPresentationEvent = CreateObject("roAssociativeArray")
		switchPresentationEvent["EventType"] = "SWITCH_PRESENTATION"
		switchPresentationEvent["Presentation"] = presentation.presentationName$
		m.msgPort.PostMessage(switchPresentationEvent)
	
		return true

	endif

	return false

End Function


Sub ExecuteMediaStateCommands(zoneHSM As Object, state As Object)

    if type(state.cmds) = "roArray" then

        for each cmd in state.cmds

			if cmd.name$ = "switchPresentation" then

				m.diagnostics.PrintDebug("switchPresentation: not supported by media state commands")

				' presentationName$ = cmd.parameters["presentationName"]

				' return m.ExecuteSwitchPresentationCommand(presentationName$)
				return

			endif

            m.ExecuteCmd(zoneHSM, cmd.name$, cmd.parameters)

        next

    endif

End Sub


Function ExecuteTransitionCommands(zoneHSM As Object, transition As Object) As Boolean

    transitionCmds = transition.transitionCmds
    if type(transitionCmds) = "roArray" then
    
        for each transitionCmd in transitionCmds
        
            command$ = transitionCmd.name$
            
            if command$ = "synchronize" then
            
                ' if the next command is synchronize, get the file to preload
                nextState$ = transition.targetMediaState$
		        zoneHSM.preloadState = zoneHSM.stateTable[nextState$]
                                       
            else if command$ = "switchPresentation" then

				presentationName$ = transitionCmd.parameters["presentationName"].GetCurrentParameterValue()

				return m.ExecuteSwitchPresentationCommand(presentationName$)

			else if command$ = "internalSynchronize" then

				if type(transition.internalSynchronizeEventsMaster) = "roAssociativeArray" then

					activeState = zoneHSM.activeState
					if type(activeState) = "roAssociativeArray" then
						activeState.internalSynchronizeEventsMaster = transition.internalSynchronizeEventsMaster
					endif

				endif

			endif

            m.ExecuteCmd(zoneHSM, transitionCmd.name$, transitionCmd.parameters)
            
        next
        
    endif

	return false

End Function


Function GetNonPrintableKeyboardCode(keyboardInput% As Integer) As String

    keyboardInput$ = LCase(StripLeadingSpaces(stri(keyboardInput%)))
    if m.nonPrintableKeyboardKeys.DoesExist(keyboardInput$) then
        return m.nonPrintableKeyboardKeys.Lookup(keyboardInput$)
    endif
    
    return ""
    
End Function


Sub InitializeNonPrintableKeyboardCodeList()
' Space				<sp>	32
' Left arrow        <la>    32848
' Right arrow       <ra>    32847
' Up arrow          <ua>    32850
' Down arrow        <da>    32849
' Return            <rn>    10
' Enter             <en>    13
' Escape            <es>    27
' Page Up           <pu>    32843
' Page Down         <pd>    32846
' F1                <f1>    32826
' F2                <f2>    32827
' F3                <f3>    32828
' F4                <f4>    32829
' F5                <f5>    32830
' F6                <f6>    32831
' F7                <f7>    32832
' F8                <f8>    32833
' F9                <f9>    32834
' F10               <f10>   32835
' F11               <f11>   32836
' F12               <f12>   32837
' F13 (Print Screen)<ps>    32838
' F14 (Scroll Lock) <sl>    32839
' F15 (Pause Break) <pb>    32840
' Backspace         <bs>    8
' Tab               <tb>    9
' Insert            <in>    32841
' Delete            <de>    127
' Home              <ho>    32842
' End               <ed>    32845
' Capslock          <cl>    32825
' Mute				<mu>	32895
' Volume down		<vd>	32897
' Volume up			<vu>	32896
' Next track		<nt>	786613
' Previous track	<pt>	786614
' Play/Pause		<pp>	786637
' Stop music		<sm>	786615
' Stop browsing		<sm>	786982
' Power				<pwr>	65665
' Back				<bk>	786980
' Forward			<fw>	786981
' Refresh			<rf>	786983


    m.nonPrintableKeyboardKeys = CreateObject("roAssociativeArray")
    m.nonPrintableKeyboardKeys.AddReplace("8","<bs>")
    m.nonPrintableKeyboardKeys.AddReplace("9","<tb>")
    m.nonPrintableKeyboardKeys.AddReplace("10","<rn>")
    m.nonPrintableKeyboardKeys.AddReplace("13","<en>")
    m.nonPrintableKeyboardKeys.AddReplace("27","<es>")
    m.nonPrintableKeyboardKeys.AddReplace("32","<sp>")
    m.nonPrintableKeyboardKeys.AddReplace("127","<de>")
    m.nonPrintableKeyboardKeys.AddReplace("32848","<la>")
    m.nonPrintableKeyboardKeys.AddReplace("32847","<ra>")
    m.nonPrintableKeyboardKeys.AddReplace("32850","<ua>")
    m.nonPrintableKeyboardKeys.AddReplace("32849","<da>")
    m.nonPrintableKeyboardKeys.AddReplace("32843","<pu>")
    m.nonPrintableKeyboardKeys.AddReplace("32846","<pd>")
    m.nonPrintableKeyboardKeys.AddReplace("32826","<f1>")
    m.nonPrintableKeyboardKeys.AddReplace("32827","<f2>")
    m.nonPrintableKeyboardKeys.AddReplace("32828","<f3>")
    m.nonPrintableKeyboardKeys.AddReplace("32829","<f4>")
    m.nonPrintableKeyboardKeys.AddReplace("32830","<f5>")
    m.nonPrintableKeyboardKeys.AddReplace("32831","<f6>")
    m.nonPrintableKeyboardKeys.AddReplace("32832","<f7>")
    m.nonPrintableKeyboardKeys.AddReplace("32833","<f8>")
    m.nonPrintableKeyboardKeys.AddReplace("32834","<f9>")
    m.nonPrintableKeyboardKeys.AddReplace("32835","<f10>")
    m.nonPrintableKeyboardKeys.AddReplace("32836","<f11>")
    m.nonPrintableKeyboardKeys.AddReplace("32837","<f12>")
    m.nonPrintableKeyboardKeys.AddReplace("32838","<ps>")
    m.nonPrintableKeyboardKeys.AddReplace("32839","<sl>")
    m.nonPrintableKeyboardKeys.AddReplace("32840","<pb>")
    m.nonPrintableKeyboardKeys.AddReplace("32841","<in>")
    m.nonPrintableKeyboardKeys.AddReplace("32842","<ho>")
    m.nonPrintableKeyboardKeys.AddReplace("32845","<ed>")
    m.nonPrintableKeyboardKeys.AddReplace("32825","<cl>")
    m.nonPrintableKeyboardKeys.AddReplace("32895","<mu>")
    m.nonPrintableKeyboardKeys.AddReplace("32897","<vd>")
    m.nonPrintableKeyboardKeys.AddReplace("32896","<vu>")
    m.nonPrintableKeyboardKeys.AddReplace("786613","<nt>")
    m.nonPrintableKeyboardKeys.AddReplace("786614","<pt>")
    m.nonPrintableKeyboardKeys.AddReplace("786637","<pp>")
    m.nonPrintableKeyboardKeys.AddReplace("786615","<sm>")
    m.nonPrintableKeyboardKeys.AddReplace("786982","<sb>")
    m.nonPrintableKeyboardKeys.AddReplace("65665","<pwr>")
    m.nonPrintableKeyboardKeys.AddReplace("786980","<bk>")
    m.nonPrintableKeyboardKeys.AddReplace("786981","<fw>")
    m.nonPrintableKeyboardKeys.AddReplace("786983","<rf>")
    
End Sub


Function ConvertToRemoteCommand(remoteCommand% As Integer) As String

	Dim remoteCommands[19]
	remoteCommands[0]="WEST"
	remoteCommands[1]="EAST"
	remoteCommands[2]="NORTH"
	remoteCommands[3]="SOUTH"
	remoteCommands[4]="SEL"
	remoteCommands[5]="EXIT"
	remoteCommands[6]="PWR"
	remoteCommands[7]="MENU"
	remoteCommands[8]="SEARCH"
	remoteCommands[9]="PLAY"
	remoteCommands[10]="FF"
	remoteCommands[11]="RW"
	remoteCommands[12]="PAUSE"
	remoteCommands[13]="ADD"
	remoteCommands[14]="SHUFFLE"
	remoteCommands[15]="REPEAT"
	remoteCommands[16]="VOLUP"
	remoteCommands[17]="VOLDWN"
	remoteCommands[18]="BRIGHT"

    if remoteCommand% < 0 or remoteCommand% > 18 return ""
    
    return remoteCommands[remoteCommand%]
    
End Function


Function GetIntegerParameterValue(parameters As Object, parameterName$ as String, defaultValue% As Integer) As Integer

	parameter = parameters[parameterName$]
	parameter$ = parameter.GetCurrentParameterValue()
	parameter% = defaultValue%
	if parameter$ <> "" then
		parameter% = int(val(parameter$))
	endif

	return parameter% 
End Function


' m is bsp
Sub ExecuteCmd(zoneHSM As Object, command$ As String, parameters As Object)

    m.diagnostics.PrintDebug("ExecuteCmd " + command$)

    if command$ = "gpioOnCommand" then
    
		gpioNumberParameter = parameters["gpioNumber"]
		gpioNumber$ = gpioNumberParameter.GetCurrentParameterValue()

        m.diagnostics.PrintDebug("Turn on gpioNumber " + gpioNumber$)
        m.controlPort.SetOutputState(int(val(gpioNumber$)), 1)
        
    else if command$ = "gpioOffCommand" then
    
		gpioNumberParameter = parameters["gpioNumber"]
		gpioNumber$ = gpioNumberParameter.GetCurrentParameterValue()
        m.diagnostics.PrintDebug("Turn off gpioNumber " + gpioNumber$)
        m.controlPort.SetOutputState(int(val(gpioNumber$)), 0)

    else if command$ = "gpioSetStateCommand" then
    
		gpioStateParameter = parameters["stateValue"]
		gpioState$ = gpioStateParameter.GetCurrentParameterValue()
        m.diagnostics.PrintDebug("Set GPIO's to " + gpioState$)
        m.controlPort.SetWholeState(int(val(gpioState$)))

    else if command$ = "mapDigitalOutputVideo" then
    
		if zoneHSM.SendCommandToVideo() then
			zone = m.GetVideoZone(zoneHSM)
			if type(zone) = "roAssociativeArray" then
				m.MapDigitalOutput(zone.videoPlayer, parameters)
			endif
		endif

    else if command$ = "mapDigitalOutputAudio" then
    
        m.MapDigitalOutput(zoneHSM.audioPlayer, parameters)

	else if command$ = "setAllAudioOutputs" then

		m.SetAllAudioOutputs(parameters)

    else if command$ = "setAudioMode" then

		m.SetAudioMode1(parameters)

	else if command$ = "setAudioOutputVideo" then
    
		if zoneHSM.SendCommandToVideo() then
			m.SetAudioOutput(zoneHSM, true, parameters)
		endif
		    
    else if command$ = "setAudioOutputAudio" then

        m.SetAudioOutput(zoneHSM, false, parameters)

    else if command$ = "setAudioModeVideo" then

		if zoneHSM.SendCommandToVideo() then
			zone = m.GetVideoZone(zoneHSM)
			if type(zone) = "roAssociativeArray" then
				m.SetAudioMode(zone.videoPlayer, parameters)
			endif
		endif

    else if command$ = "setAudioModeAudio" then

        m.SetAudioMode(zoneHSM.audioPlayer, parameters)

    else if command$ = "mapStereoOutputVideo" then

		if zoneHSM.SendCommandToVideo() then
			m.MapStereoOutput(zoneHSM, true, parameters)
		endif

    else if command$ = "mapStereoOutputAudio" then

        m.MapStereoOutput(zoneHSM, false, parameters)

    else if command$ = "muteAudioOutputs" then

		m.MuteAudioOutputs(true, parameters)

	else if command$ = "unmuteAudioOutputs" then

		m.MuteAudioOutputs(false, parameters)

	else if command$ = "setConnectorVolume" then

		m.SetConnectorVolume(parameters)

	else if command$ = "incrementConnectorVolume" then

		m.ChangeConnectorVolume(1, parameters)

	else if command$ = "decrementConnectorVolume" then

		m.ChangeConnectorVolume(-1, parameters)

	else if command$ = "setZoneVolume" then

		m.SetZoneVolume(parameters)

	else if command$ = "incrementZoneVolume" then

		m.ChangeZoneVolume(1, parameters)

	else if command$ = "decrementZoneVolume" then

		m.ChangeZoneVolume(-1, parameters)

	else if command$ = "setZoneChannelVolume" then

		m.SetZoneChannelVolume(parameters)

	else if command$ = "incrementZoneChannelVolume" then

		m.ChangeZoneChannelVolume(1, parameters)

	else if command$ = "decrementZoneChannelVolume" then

		m.ChangeZoneChannelVolume(-1, parameters)

	else if command$ = "setSpdifMuteVideo" then

		if zoneHSM.SendCommandToVideo() then
			zone = m.GetVideoZone(zoneHSM)
			if type(zone) = "roAssociativeArray" then
				m.SetSpdifMute(zone.videoPlayer, parameters)
			endif
		endif

    else if command$ = "setSpdifMuteAudio" then

        m.SetSpdifMute(zoneHSM.audioPlayer, parameters)

    else if command$ = "setAnalogMuteVideo" then

		if zoneHSM.SendCommandToVideo() then
			zone = m.GetVideoZone(zoneHSM)
			if type(zone) = "roAssociativeArray" then
				m.SetAnalogMute(zone.videoChannelVolumes, zone.videoPlayer, parameters)
			endif
		endif

    else if command$ = "setAnalogMuteAudio" then

        m.SetAnalogMute(zoneHSM.audioChannelVolumes, zoneHSM.audioPlayer, parameters)

	else if command$ = "setHDMIMute" then
	
		m.SetHDMIMute(parameters)
		
	else if command$ = "setVideoVolumeByConnector" then
	
		if zoneHSM.SendCommandToVideo() then

			outputParameter = parameters["output"]
			volumeParameter = parameters["volume"]

			output$ = outputParameter.GetCurrentParameterValue()
			volume$ = volumeParameter.GetCurrentParameterValue()

			m.diagnostics.PrintDebug("Set video volume on output " + output$ + " to " + volume$)
			m.SetVideoVolumeByConnector(zoneHSM, output$, volume$)

		endif

    else if command$ = "incrementVideoVolumeByConnector" then

		if zoneHSM.SendCommandToVideo() then

			outputParameter = parameters["output"]
			volumeDeltaParameter = parameters["volumeDelta"]

			output$ = outputParameter.GetCurrentParameterValue()
			volumeDelta$ = volumeDeltaParameter.GetCurrentParameterValue()
		
			m.diagnostics.PrintDebug("Increment video volume on output " + output$ + " by " + volumeDelta$)

			m.IncrementVideoVolumeByConnector(zoneHSM, output$, volumeDelta$)
		
		endif

    else if command$ = "decrementVideoVolumeByConnector" then

		if zoneHSM.SendCommandToVideo() then

			outputParameter = parameters["output"]
			volumeDeltaParameter = parameters["volumeDelta"]

			output$ = outputParameter.GetCurrentParameterValue()
			volumeDelta$ = volumeDeltaParameter.GetCurrentParameterValue()
		
			m.diagnostics.PrintDebug("Decrement video volume on output " + output$ + " by " + volumeDelta$)

			m.DecrementVideoVolumeByConnector(zoneHSM, output$, volumeDelta$)

		endif

    else if command$ = "setVideoVolume" then
    
		if zoneHSM.SendCommandToVideo() then

			volumeParameter = parameters["volume"]
			volume$ = volumeParameter.GetCurrentParameterValue()

			m.diagnostics.PrintDebug("Set video volume to " + volume$)
			m.SetVideoVolume(zoneHSM, volume$)

		endif

    else if command$ = "incrementVideoVolume" then

		if zoneHSM.SendCommandToVideo() then

			volumeDeltaParameter = parameters["volumeDelta"]
			volumeDelta$ = volumeDeltaParameter.GetCurrentParameterValue()
		
			m.diagnostics.PrintDebug("Increment video volume by " + volumeDelta$)
			m.IncrementVideoVolume(zoneHSM, volumeDelta$)

		endif

    else if command$ = "decrementVideoVolume" then
    
		if zoneHSM.SendCommandToVideo() then

			volumeDeltaParameter = parameters["volumeDelta"]
			volumeDelta$ = volumeDeltaParameter.GetCurrentParameterValue()
		
			m.diagnostics.PrintDebug("Decrement video volume by " + volumeDelta$)
			m.DecrementVideoVolume(zoneHSM, volumeDelta$)

		endif

	else if command$ = "setAudioVolumeByConnector" then
	
		outputParameter = parameters["output"]
		volumeParameter = parameters["volume"]

		output$ = outputParameter.GetCurrentParameterValue()
		volume$ = volumeParameter.GetCurrentParameterValue()

        m.diagnostics.PrintDebug("Set audio volume on analog " + output$ + " to " + volume$)
		m.SetAudioVolumeByConnector(zoneHSM, output$, volume$)

    else if command$ = "incrementAudioVolumeByConnector" then

		outputParameter = parameters["output"]
		output$ = outputParameter.GetCurrentParameterValue()
		volumeDeltaParameter = parameters["volumeDelta"]
		volumeDelta$ = volumeDeltaParameter.GetCurrentParameterValue()

		m.diagnostics.PrintDebug("Increment audio volume on output " + output$ + " by " + volumeDelta$)
		m.IncrementAudioVolumeByConnector(zoneHSM, output$, volumeDelta$)
		
    else if command$ = "decrementAudioVolumeByConnector" then

		outputParameter = parameters["output"]
		output$ = outputParameter.GetCurrentParameterValue()
		volumeDeltaParameter = parameters["volumeDelta"]
		volumeDelta$ = volumeDeltaParameter.GetCurrentParameterValue()

		m.diagnostics.PrintDebug("Decrement audio volume on output " + output$ + " by " + volumeDelta$)
		m.DecrementAudioVolumeByConnector(zoneHSM, output$, volumeDelta$)
		
    else if command$ = "setAudioVolume" then
    
		volumeParameter = parameters["volume"]
		volume$ = volumeParameter.GetCurrentParameterValue()

        m.diagnostics.PrintDebug("Set audio volume to " + volume$)
        m.SetAudioVolume(zoneHSM, volume$)

    else if command$ = "incrementAudioVolume" then
    
		if IsAudioPlayer(zoneHSM.audioPlayer) then
			volumeDeltaParameter = parameters["volumeDelta"]
			volumeDelta$ = volumeDeltaParameter.GetCurrentParameterValue()
			m.diagnostics.PrintDebug("Increment audio volume by " + volumeDelta$)
			m.IncrementAudioVolume(zoneHSM, volumeDelta$, zoneHSM.audioPlayerAudioSettings.maxVolume%)
		endif
		
    else if command$ = "decrementAudioVolume" then
    
		if IsAudioPlayer(zoneHSM.audioPlayer) then
			volumeDeltaParameter = parameters["volumeDelta"]
			volumeDelta$ = volumeDeltaParameter.GetCurrentParameterValue()
			m.diagnostics.PrintDebug("Decrement audio volume by " + volumeDelta$)
			m.DecrementAudioVolume(zoneHSM, volumeDelta$, zoneHSM.audioPlayerAudioSettings.minVolume%)
		endif
		
    else if command$ = "setVideoChannelVolumes" then
    	
		if zoneHSM.SendCommandToVideo() then

			channelMaskParameter = parameters["channel"]
			channelMask$ = channelMaskParameter.GetCurrentParameterValue()

			volumeParameter = parameters["volume"]
			volume$ = volumeParameter.GetCurrentParameterValue()

			m.diagnostics.PrintDebug("Set video channel volume: channel = " + channelMask$ + ", volume = " + volume$)
			m.SetVideoChannnelVolume(zoneHSM, channelMask$, volume$)
        
		endif

    else if command$ = "incrementVideoChannelVolumes" then
    
		if zoneHSM.SendCommandToVideo() then

			channelMaskParameter = parameters["channel"]
			channelMask$ = channelMaskParameter.GetCurrentParameterValue()

			volumeDeltaParameter = parameters["volumeDelta"]
			volumeDelta$ = volumeDeltaParameter.GetCurrentParameterValue()

			m.diagnostics.PrintDebug("Increment video channel volumes: channel = " + channelMask$ + ", volume delta = " + volumeDelta$)
			m.IncrementVideoChannnelVolumes(zoneHSM, channelMask$, volumeDelta$)
        
		endif

    else if command$ = "decrementVideoChannelVolumes" then
            
		if zoneHSM.SendCommandToVideo() then

			channelMaskParameter = parameters["channel"]
			channelMask$ = channelMaskParameter.GetCurrentParameterValue()

			volumeDeltaParameter = parameters["volumeDelta"]
			volumeDelta$ = volumeDeltaParameter.GetCurrentParameterValue()

			m.diagnostics.PrintDebug("Decrement video channel volumes: channel = " + channelMask$ + ", volume delta = " + volumeDelta$)
			m.DecrementVideoChannnelVolumes(zoneHSM, channelMask$, volumeDelta$)
      
	  endif
	    
    else if command$ = "setAudioChannelVolumes" then
    
		channelMaskParameter = parameters["channel"]
		channelMask$ = channelMaskParameter.GetCurrentParameterValue()

		volumeParameter = parameters["volume"]
		volume$ = volumeParameter.GetCurrentParameterValue()

        m.diagnostics.PrintDebug("Set audio channel volume: channel = " + channelMask$ + ", volume = " + volume$)
        m.SetAudioChannnelVolume(zoneHSM, channelMask$, volume$)
        
    else if command$ = "incrementAudioChannelVolumes" then
    
		channelMaskParameter = parameters["channel"]
		channelMask$ = channelMaskParameter.GetCurrentParameterValue()

		volumeDeltaParameter = parameters["volumeDelta"]
		volumeDelta$ = volumeDeltaParameter.GetCurrentParameterValue()

        m.diagnostics.PrintDebug("Increment audio channel volumes: channel = " + channelMask$ + ", volume delta = " + volumeDelta$)
        m.IncrementAudioChannelVolumes(zoneHSM, channelMask$, volumeDelta$)
        
    else if command$ = "decrementAudioChannelVolumes" then
            
		channelMaskParameter = parameters["channel"]
		channelMask$ = channelMaskParameter.GetCurrentParameterValue()

		volumeDeltaParameter = parameters["volumeDelta"]
		volumeDelta$ = volumeDeltaParameter.GetCurrentParameterValue()

        m.diagnostics.PrintDebug("Decrement audio channel volumes: channel = " + channelMask$ + ", volume delta = " + volumeDelta$)
        m.DecrementAudioChannelVolumes(zoneHSM, channelMask$, volumeDelta$)
        
    else if command$ = "sendSerialStringCommand" then
    
		portParameter = parameters["port"]
		port$ = portParameter.GetCurrentParameterValue()

		serialStringParameter = parameters["serialString"]
		serialString$ = serialStringParameter.GetCurrentParameterValue()

        m.diagnostics.PrintDebug("sendSerialStringCommand " + serialString$ + " to port " + port$)
        
        if type(m.serial) = "roAssociativeArray" then
            serial = m.serial[port$]
            if type(serial) = "roSerialPort" then
                serial.SendLine(serialString$)
            endif
        endif
        
    else if command$ = "sendSerialBlockCommand" then
    
		portParameter = parameters["port"]
		port$ = portParameter.GetCurrentParameterValue()

		serialStringParameter = parameters["serialString"]
		serialString$ = serialStringParameter.GetCurrentParameterValue()

        m.diagnostics.PrintDebug("sendSerialBlockCommand " + serialString$ + " to port " + port$)
        
        if type(m.serial) = "roAssociativeArray" then
            serial = m.serial[port$]
            if type(serial) = "roSerialPort" then
                serial.SendBlock(serialString$)
            endif
        endif
        
    else if command$ = "sendSerialByteCommand" then

		portParameter = parameters["port"]
		port$ = portParameter.GetCurrentParameterValue()

		byteValueParameter = parameters["byteValue"]
		byteValue$ = byteValueParameter.GetCurrentParameterValue()
    
        m.diagnostics.PrintDebug("sendSerialByteCommand " + byteValue$ + " to port " + port$)
        
        if type(m.serial) = "roAssociativeArray" then
            serial = m.serial[port$]
            if type(serial) = "roSerialPort" then
                serial.SendByte(int(val(byteValue$)))
            endif
        endif
        
    else if command$ = "sendSerialBytesCommand" then

		portParameter = parameters["port"]
		port$ = portParameter.GetCurrentParameterValue()

		byteValueParameter = parameters["byteValues"]
		byteValues$ = byteValueParameter.GetCurrentParameterValue()
    
        m.diagnostics.PrintDebug("sendSerialBytesCommand " + byteValues$ + " to port " + port$)
        
        if type(m.serial) = "roAssociativeArray" then
            serial = m.serial[port$]
            if type(serial) = "roSerialPort" then
                byteString$ = StripLeadingSpaces(byteValues$)
                if len(byteString$) > 0 then
                    commaPosition = -1
    	            while commaPosition <> 0	
    		            commaPosition = instr(1, byteString$, ",")
			            if commaPosition = 0 then
				            serial.SendByte(val(byteString$))					
			            else 
				            serial.SendByte(val(left(byteString$, commaPosition - 1)))
			            endif
			            byteString$ = mid(byteString$, commaPosition+1)
    	            end while
                endif
            endif
        endif

    else if command$ = "sendUDPCommand" then

		udpStringParameter = parameters["udpString"]
		udpString$ = udpStringParameter.GetCurrentParameterValue()

        m.diagnostics.PrintDebug("Send UDP command " + udpString$)
        m.udpSender.Send(udpString$)
    
    else if command$ = "sendIRRemote" then
    
		irRemoteOutParameter = parameters["irRemoteOut"]
		irRemoteOut$ = irRemoteOutParameter.GetCurrentParameterValue()
        
        if instr(1, irRemoteOut$, "b-") = 1 then
			irRemoteOut$ = mid(irRemoteOut$, 3)
			m.diagnostics.PrintDebug("Send Bose IR Remote " + irRemoteOut$)
			protocol$ = "Bose Sounddock"
        else
	        m.diagnostics.PrintDebug("Send IR Remote " + irRemoteOut$)
			protocol$ = "NEC"
        endif
        
        if type(m.remote) <> "roIRRemote" then
            m.remote = CreateObject("roIRRemote")
            m.remote.SetPort(m.msgPort)
        endif
        
        if type(m.remote) = "roIRRemote" then
            irRemoteOut% = int(val(irRemoteOut$))
            m.remote.Send(protocol$, irRemoteOut%)
        endif

    else if command$ = "sendBLC400Output" then

		controllerIndexParameter = parameters["controllerIndex"]
		controllerIndex$ = controllerIndexParameter.GetCurrentParameterValue()
        controllerIndex% = int(val(controllerIndex$))

		if type(m.blcs[controllerIndex%]) = "roControlPort" then

			CHANNEL_CMD_INTENSITY% = &h1000
			CHANNEL_CMD_BLINK%     = &h1100
			CHANNEL_CMD_BREATHE%   = &h1200
			CHANNEL_CMD_STROBE%    = &h1300
			CHANNEL_CMD_MARQUEE%   = &h1400

			' blink mode enumeration
			BLINK_SPEED_SLOW%   = &h20
			BLINK_SPEED_MEDIUM% = &h21
			BLINK_SPEED_FAST%   = &h22

			' marquee sub commands
			MARQUEE_EXECUTE%    = &h30
			MARQUEE_ON_TIME%    = &h31
			MARQUEE_OFF_TIME%   = &h32
			MARQUEE_FADE_OUT%   = &h33
			MARQUEE_PLAYBACK%   = &h34
			MARQUEE_TRANSITION% = &h35
			MARQUEE_INTENSITY%  = &h36

			' marquee playback mode enumeration
			MARQUEE_PLAYBACK_LOOP%   = &h40
			MARQUEE_PLAYBACK_BOUNCE% = &h41
			MARQUEE_PLAYBACK_ONCE%   = &h42
			MARQUEE_PLAYBACK_RANDOM% = &h43

			' marquee transition mode enumeration
			MARQUEE_TRANSITION_OFF%     = &h50
			MARQUEE_TRANSITION_FULL%    = &h51
			MARQUEE_TRANSITION_OVERLAP% = &h52

			controlCmd = CreateObject("roArray", 4, false)

			effectParameter = parameters["effect"]
			effect$ = effectParameter.GetCurrentParameterValue()

			channelsParameter = parameters["channels"]
			channels$ = channelsParameter.GetCurrentParameterValue()
			channels% = int(val(channels$))

			time% = GetIntegerParameterValue(parameters, "time", 0)

			intensity% = GetIntegerParameterValue(parameters, "intensity", 100)

			blinkRateParameter = parameters["blinkRate"]
			blinkRate$ = blinkRateParameter.GetCurrentParameterValue()

			minimumIntensity% = GetIntegerParameterValue(parameters, "minimumIntensity", 0)
			maximumIntensity% = GetIntegerParameterValue(parameters, "maximumIntensity", 100)

			controlCmd[0] = channels%

			if effect$ = "intensity" then

				controlCmd[0] = CHANNEL_CMD_INTENSITY% or channels%
				controlCmd[1] = time%                ' time in seconds for transition (zero for instantaneous)
				controlCmd[2] = intensity%           ' target intensity
				controlCmd[3] = 0					 ' unused

		        m.diagnostics.PrintDebug("sendBLC400Output - intensity: time = " + stri(time%) + " intensity = " + stri(intensity%))

			else if effect$ = "blink" then

				if blinkRate$ = "fast" then
					blinkRate% = BLINK_SPEED_FAST%
				else if blinkRate$ = "medium" then
					blinkRate% = BLINK_SPEED_MEDIUM%
				else
					blinkRate% = BLINK_SPEED_SLOW%
				endif

				controlCmd[ 0 ] = CHANNEL_CMD_BLINK% or channels%
				controlCmd[ 1 ] = blinkRate%		   ' blink mode
				controlCmd[ 2 ] = 100                  ' intensity (0 = use current value)
				controlCmd[ 3 ] = 0                    ' unused

		        m.diagnostics.PrintDebug("sendBLC400Output - blink: blinkRate = " + blinkRate$)

			else if effect$ = "breathe" then

				controlCmd[ 0 ] = CHANNEL_CMD_BREATHE% or channels%
				controlCmd[ 1 ] = time%                   ' time in seconds for change (zero for instantaneous)
				controlCmd[ 2 ] = minimumIntensity%       ' min intensity (or rather starting intensity)
				controlCmd[ 3 ] = maximumIntensity%       ' max intensity

		        m.diagnostics.PrintDebug("sendBLC400Output - breathe: time = " + stri(time%) + " minimumIntensity = " + stri(minimumIntensity%) + " maximumIntensity = " + stri(maximumIntensity%))

			else if effect$ = "strobe" then

				controlCmd[ 0 ] = CHANNEL_CMD_STROBE% or channels%
				controlCmd[ 1 ] = time%                ' time in milliseconds for strobe
				controlCmd[ 2 ] = intensity%           ' intensity (0 = use current value)
				controlCmd[ 3 ] = 0                    ' unused

		        m.diagnostics.PrintDebug("sendBLC400Output - strobe: time = " + stri(time%) + " intensity = " + stri(intensity%))

			else if effect$ = "marquee" then

				lightOnTime% = GetIntegerParameterValue(parameters, "lightOnTime", 0)
				lightOffTime% = GetIntegerParameterValue(parameters, "lightOffTime", 0)

				transitionModeParameter = parameters["transitionMode"]
				transitionMode$ = transitionModeParameter.GetCurrentParameterValue()

				playbackModeParameter = parameters["playbackMode"]
				playbackMode$ = playbackModeParameter.GetCurrentParameterValue()

				if playbackMode$ = "loop" then
					playbackMode% = MARQUEE_PLAYBACK_LOOP%
				else if playbackMode$ = "backAndForth" then
					playbackMode% = MARQUEE_PLAYBACK_BOUNCE%
				else if playbackMode$ = "playOnce" then
					playbackMode% = MARQUEE_PLAYBACK_ONCE%
				else
					playbackMode% = MARQUEE_PLAYBACK_RANDOM%
				endif

		        m.diagnostics.PrintDebug("sendBLC400Output - marquee: mode = " + playbackMode$)

				transitionMode% = MARQUEE_TRANSITION_OFF%

				if transitionMode$ = "hard" then
					fadeOut% = 0
				else
					fadeOut% = 1

					if transitionMode$ = "smoothFull" then
						transitionMode% = MARQUEE_TRANSITION_FULL%
					else if transitionMode$ = "smoothOverlap"
						transitionMode% = MARQUEE_TRANSITION_OVERLAP%
					endif

				endif

				controlCmd[ 0 ] = CHANNEL_CMD_MARQUEE%
				controlCmd[ 1 ] = MARQUEE_PLAYBACK%			' changing playback mode
				controlCmd[ 2 ] = playbackMode%				' playback mode
				controlCmd[ 3 ] = 0							' unused

				m.blcs[controllerIndex%].SetOutputValues(controlCmd)

				controlCmd[ 0 ] = CHANNEL_CMD_MARQUEE%
				controlCmd[ 1 ] = MARQUEE_FADE_OUT%			' fadeOut
				controlCmd[ 2 ] = fadeOut%					' hard or soft
				controlCmd[ 3 ] = 0							' unused

				m.blcs[controllerIndex%].SetOutputValues(controlCmd)

				controlCmd[ 0 ] = CHANNEL_CMD_MARQUEE%
				controlCmd[ 1 ] = MARQUEE_TRANSITION%			
				controlCmd[ 2 ] = transitionMode%					
				controlCmd[ 3 ] = 0							' unused

				m.blcs[controllerIndex%].SetOutputValues(controlCmd)

				controlCmd[ 0 ] = CHANNEL_CMD_MARQUEE%
				controlCmd[ 1 ] = MARQUEE_ON_TIME%			' on time
				controlCmd[ 2 ] = lightOnTime%				' msec
				controlCmd[ 3 ] = 0							' unused

				m.blcs[controllerIndex%].SetOutputValues(controlCmd)

				controlCmd[ 0 ] = CHANNEL_CMD_MARQUEE%
				controlCmd[ 1 ] = MARQUEE_OFF_TIME%			' off time
				controlCmd[ 2 ] = lightOffTime%				' msec
				controlCmd[ 3 ] = 0							' unused

				m.blcs[controllerIndex%].SetOutputValues(controlCmd)

				controlCmd[ 0 ] = CHANNEL_CMD_MARQUEE% or channels%
				controlCmd[ 1 ] = MARQUEE_EXECUTE%         ' marquee sub command
				controlCmd[ 2 ] = 0                        ' unused
				controlCmd[ 3 ] = 0                        ' unused

			endif

			m.blcs[controllerIndex%].SetOutputValues(controlCmd)

		endif

	else if command$ = "sendBPOutput" then
    
		buttonPanelIndexParameter = parameters["buttonPanelIndex"]
		buttonPanelIndex$ = buttonPanelIndexParameter.GetCurrentParameterValue()
        buttonPanelIndex% = int(val(buttonPanelIndex$))

		buttonNumberParameter = parameters["buttonNumber"]
		buttonNumber$ = buttonNumberParameter.GetCurrentParameterValue()

		actionParameter = parameters["action"]
		action$ = actionParameter.GetCurrentParameterValue()

        if type(m.bpOutput[buttonPanelIndex%]) = "roControlPort" then
        
            m.diagnostics.PrintDebug("Apply action " + action$ + " to BP button " + buttonNumber$)

            buttonNumber% = int(val(buttonNumber$))

            if buttonNumber% = -1 then
				for i% = 0 to 10
					if action$ = "on" then
						m.bpOutput[buttonPanelIndex%].SetOutputState(i%, 1)            
					else if action$ = "off" then
						m.bpOutput[buttonPanelIndex%].SetOutputState(i%, 0)            
					else if action$ = "fastBlink" then
						m.bpOutput[buttonPanelIndex%].SetOutputValue(i%, &h038e38c)
					else if action$ = "mediumBlink" then
						m.bpOutput[buttonPanelIndex%].SetOutputValue(i%, &h03f03e0)
					else if action$ = "slowBlink" then
						m.bpOutput[buttonPanelIndex%].SetOutputValue(i%, &h03ff800)
					endif
				next
            else
				if action$ = "on" then
					m.bpOutput[buttonPanelIndex%].SetOutputState(buttonNumber%, 1)            
				else if action$ = "off" then
					m.bpOutput[buttonPanelIndex%].SetOutputState(buttonNumber%, 0)            
				else if action$ = "fastBlink" then
					m.bpOutput[buttonPanelIndex%].SetOutputValue(buttonNumber%, &h038e38c)
				else if action$ = "mediumBlink" then
					m.bpOutput[buttonPanelIndex%].SetOutputValue(buttonNumber%, &h03f03e0)
				else if action$ = "slowBlink" then
					m.bpOutput[buttonPanelIndex%].SetOutputValue(buttonNumber%, &h03ff800)
				endif
            endif
            
        endif        

    else if command$ = "synchronize" then

		synchronizeKeywordParameter = parameters["synchronizeKeyword"]
		synchronizeKeyword$ = synchronizeKeywordParameter.GetCurrentParameterValue()

        m.diagnostics.PrintDebug("Send synchronize command " + synchronizeKeyword$)
    
	    m.udpSender.Send("pre-" + synchronizeKeyword$)
	    
        preloadRequired = true
        if type(zoneHSM.preloadState) = "roAssociativeArray" then
            if zoneHSM.preloadedStateName$ = zoneHSM.preloadState.name$ then
                preloadRequired = false
            endif
        endif                                    

        ' currently only support preload / synchronizing with images and videos
        if preloadRequired then
            zoneHSM.preloadState.PreloadItem()
	    endif
	    
	    sleep(300)
	    
	    ' m.udpSender.Send("ply-" + synchronizeKeyword$)
	    
	    if type(m.udpReceiver) = "roDatagramReceiver" then
	        udpReceiverExists = true
	        m.udpReceiver = 0
	    else
	        udpReceiverExists = false
	    endif
	    
	    m.WaitForSyncResponse(synchronizeKeyword$)
	    
	    if udpReceiverExists then
	        m.udpReceiver = CreateObject("roDatagramReceiver", m.udpReceivePort)
            m.udpReceiver.SetPort(m.msgPort)
	    endif

	else if command$ = "sendZoneMessage" then
	
        m.diagnostics.PrintDebug("Execute sendZoneMessage command")

		zoneMessageParameter = parameters["zoneMessage"]
		sendZoneMessageParameter$ = zoneMessageParameter.GetCurrentParameterValue()

		' send ZoneMessage message
		zoneMessageCmd = CreateObject("roAssociativeArray")
		zoneMessageCmd["EventType"] = "SEND_ZONE_MESSAGE"
		zoneMessageCmd["EventParameter"] = sendZoneMessageParameter$
		m.msgPort.PostMessage(zoneMessageCmd)

    else if command$ = "internalSynchronize" then

        m.diagnostics.PrintDebug("Execute internalSynchronize command")

		internalSyncParameter = parameters["synchronizeKeyword"]
		internalSyncParameter$ = internalSyncParameter.GetCurrentParameterValue()

' send InternalSyncPreload message
		internalSyncPreload = CreateObject("roAssociativeArray")
		internalSyncPreload["EventType"] = "INTERNAL_SYNC_PRELOAD"
		internalSyncPreload["EventParameter"] = internalSyncParameter$
		m.msgPort.PostMessage(internalSyncPreload)

' send InternalSyncMasterPreload message
		internalSyncMasterPreload = CreateObject("roAssociativeArray")
		internalSyncMasterPreload["EventType"] = "INTERNAL_SYNC_MASTER_PRELOAD"
		internalSyncMasterPreload["EventParameter"] = internalSyncParameter$
		m.msgPort.PostMessage(internalSyncMasterPreload)

' current state is zoneHSM.activeState
		activeState = zoneHSM.activeState
		if type(activeState) = "roAssociativeArray" then
			if type(activeState.internalSynchronizeEventsMaster) = "roAssociativeArray" then
				if type(activeState.internalSynchronizeEventsMaster[internalSyncParameter$]) = "roAssociativeArray" then
					transition = activeState.internalSynchronizeEventsMaster[internalSyncParameter$]
					nextState$ = transition.targetMediaState$
					if nextState$ <> "" then
						zoneHSM.preloadState = zoneHSM.stateTable[nextState$]
						zoneHSM.preloadState.PreloadItem()
					endif
				endif

			endif
		endif

	else if command$ = "reboot" then
		
		m.diagnostics.PrintDebug("Reboot")
        RebootSystem()

	else if command$ = "sendUSBBinaryEtapBytesCommand" then
	
		byteValuesParameter = parameters["byteValues"]
		byteValues$ = byteValuesParameter.GetCurrentParameterValue()

        m.diagnostics.PrintDebug("sendUSBBinaryEtapBytesCommand " + byteValues$)
        
        if type(m.usbBinaryEtap) <> "roUsbBinaryEtap" then
			m.usbBinaryEtap = CreateObject("roUsbBinaryEtap", 0)
        endif

        if type(m.usbBinaryEtap) = "roUsbBinaryEtap" then
			ba = CreateObject("roByteArray")
            byteString$ = StripLeadingSpaces(byteValues$)
            if len(byteString$) > 0 then
                commaPosition = -1
	            while commaPosition <> 0	
		            commaPosition = instr(1, byteString$, ",")
		            if commaPosition = 0 then
						ba.push(val(byteString$))
		            else 
			            ba.push(val(left(byteString$, commaPosition - 1)))
		            endif
		            byteString$ = mid(byteString$, commaPosition+1)
	            end while
				m.usbBinaryEtap.Send(ba)
            endif
        endif
        	        	
	else if command$ = "cecDisplayOn" then
	
        m.diagnostics.PrintDebug("Display On")
        m.CecDisplayOn()

	else if command$ = "cecDisplayOff" then
	
        m.diagnostics.PrintDebug("Display Off")
        m.CecDisplayOff()

	else if command$ = "cecSendString" then
	
		cecCommandParameter = parameters["cecAsciiString"]
		cecCommand$ = cecCommandParameter.GetCurrentParameterValue()

		m.diagnostics.PrintDebug("cecSendString " + cecCommand$)
		m.SendCecCommand(cecCommand$)
		
	else if command$ = "cecPhilipsSetVolume" then

		volumeParameter = parameters["volume"]
		volume$ = volumeParameter.GetCurrentParameterValue()

        m.diagnostics.PrintDebug("Set cec Philips volume to " + volume$)
        volume% = int(val(volume$))
		m.CecPhilipsSetVolume(volume%)
		
    else if command$ = "pauseVideoCommand" then
    
        m.diagnostics.PrintDebug("Pause video")
        m.PauseVideo(zoneHSM)

    else if command$ = "resumeVideoCommand" then
    
        m.diagnostics.PrintDebug("Resume video")
        m.ResumeVideo(zoneHSM)

    else if command$ = "enablePowerSaveMode" then
    
        m.diagnostics.PrintDebug("Enable Power Save Mode")
        m.SetPowerSaveMode(true)

    else if command$ = "disablePowerSaveMode" then
    
        m.diagnostics.PrintDebug("Disable Power Save Mode")
        m.SetPowerSaveMode(false)

    else if command$ = "pause" then
    
		pauseTimeParameter = parameters["pauseTime"]
		pauseTime$ = pauseTimeParameter.GetCurrentParameterValue()

        m.diagnostics.PrintDebug("Pause for " + pauseTime$ + " milliseconds")
        pauseTime% = int(val(pauseTime$))
        sleep(pauseTime%)

	else if command$ = "setVariable" then

		variableNameParameter = parameters["variableName"]
		variableValueParameter = parameters["variableValue"]

		variableName$ = variableNameParameter.GetVariableName()
		variableValue$ = variableValueParameter.GetCurrentParameterValue()

		userVariable = m.GetUserVariable(variableName$)
		if type(userVariable) = "roAssociativeArray" then
			userVariable.SetCurrentValue(variableValue$, true)
		else
	        m.diagnostics.PrintDebug("User variable " + variableName$ + " not found.")
		    m.logging.WriteDiagnosticLogEntry(m.diagnosticCodes.EVENT_USER_VARIABLE_NOT_FOUND, variableName$)
		endif

	else if command$ = "incrementVariable" then

		m.ChangeUserVariableValue(parameters, 1)

	else if command$ = "decrementVariable" then

		m.ChangeUserVariableValue(parameters, -1)

	else if command$ = "resetVariables" then

		m.ResetVariables()

	else if command$ = "configureAudioResources" then

        m.diagnostics.PrintDebug("Configure Audio Resources")
        zoneHSM.ConfigureAudioResources()

	endif
	
End Sub


Sub ChangeUserVariableValue(parameters As Object, delta% As Integer)

	variableNameParameter = parameters["variableName"]
	variableName$ = variableNameParameter.GetVariableName()

	userVariable = m.GetUserVariable(variableName$)
	if type(userVariable) = "roAssociativeArray" then
		currentValue% = val(userVariable.GetCurrentValue())
		currentValue% = currentValue% + delta%
		userVariable.SetCurrentValue(StripleadingSpaces(stri(currentValue%)), true)
	else
		m.diagnostics.PrintDebug("User variable " + variableName$ + " not found.")
		m.logging.WriteDiagnosticLogEntry(m.diagnosticCodes.EVENT_USER_VARIABLE_NOT_FOUND, variableName$)
	endif

End Sub


Sub ChangeRFChannel(zone As Object, channelDelta% As Integer)

	startingChannel% = zone.currentChannelIndex%

' loop unnecessary if we don't support ignoreChannel
	while true

		zone.currentChannelIndex% = zone.currentChannelIndex% + channelDelta%

		if zone.currentChannelIndex% < 0 then
			zone.currentChannelIndex% = m.scannedChannels.Count() - 1
		endif

		if zone.currentChannelIndex% >= m.scannedChannels.Count() then
			zone.currentChannelIndex% = 0
		endif

		return

'		if not m.scannedChannels[zone.currentChannelIndex%].ignoreChannel return

		if zone.currentChannelIndex% = startingChannel% return

	end while

End Sub


Function STTopEventHandler(event As Object, stateData As Object) As Object
	
    stateData.nextState = invalid
    return "IGNORED"
    
End Function


Function GetPoolFilePath(syncPoolFiles As Object, fileName$ As String) As String

    if type(syncPoolFiles) = "roSyncPoolFiles" then
        return syncPoolFiles.GetPoolFilePath(fileName$)
    else
        return fileName$
    endif

End Function

'endregion

'region Logging
REM *******************************************************
REM *******************************************************
REM ***************                    ********************
REM *************** LOGGING OBJECT     ********************
REM ***************                    ********************
REM *******************************************************
REM *******************************************************

REM
REM construct a new logging BrightScript object
REM
Function newLogging() As Object

    logging = CreateObject("roAssociativeArray")
    
    logging.bsp = m
    logging.msgPort = m.msgPort
    logging.systemTime = m.systemTime
    logging.diagnostics = m.diagnostics
    
    logging.SetSystemInfo = SetSystemInfo

    logging.CreateLogFile = CreateLogFile
    logging.MoveExpiredCurrentLog = MoveExpiredCurrentLog
    logging.MoveCurrentLog = MoveCurrentLog
    logging.InitializeLogging = InitializeLogging
    logging.ReinitializeLogging = ReinitializeLogging
    logging.InitializeCutoverTimer = InitializeCutoverTimer
    logging.WritePlaybackLogEntry = WritePlaybackLogEntry
    logging.WriteEventLogEntry = WriteEventLogEntry
	logging.WriteStateLogEntry = WriteStateLogEntry
    logging.WriteDiagnosticLogEntry = WriteDiagnosticLogEntry
    logging.PushLogFile = PushLogFile
    logging.CutoverLogFile = CutoverLogFile
    logging.HandleTimerEvent = HandleLoggingTimerEvent
    logging.PushLogFilesOnBoot = PushLogFilesOnBoot
    logging.OpenOrCreateCurrentLog = OpenOrCreateCurrentLog
    logging.DeleteExpiredFiles = DeleteExpiredFiles
    logging.DeleteOlderFiles = DeleteOlderFiles
    logging.DeleteLogFiles = DeleteLogFiles
    logging.DeleteAllLogFiles = DeleteAllLogFiles
	logging.GetLogFiles = GetLogFiles
	logging.CopyAllLogFiles = CopyAllLogFiles
	logging.CopyLogFiles = CopyLogFiles
    logging.FlushLogFile = FlushLogFile
	logging.UpdateLogCounter = UpdateLogCounter
    logging.logFile = invalid
    
    logging.uploadLogFolder = "logs"
    logging.uploadLogArchiveFolder = "archivedLogs"
    logging.uploadLogFailedFolder = "failedLogs"
    logging.logFileUpload = invalid
    
    logging.playbackLoggingEnabled = false
    logging.eventLoggingEnabled = false
    logging.diagnosticLoggingEnabled = false
    logging.stateLoggingEnabled = false
    logging.uploadLogFilesAtBoot = false
    logging.uploadLogFilesAtSpecificTime = false
    logging.uploadLogFilesTime% = 0
    
	logging.useDate = logging.systemTime.IsValid()

    return logging
    
End Function


Function UpdateLogCounter(logCounter$ As String, maxValue% As Integer, numDigits% As Integer, writeToRegistry As Boolean) As String

	logCounter% = val(logCounter$)
	logCounter% = logCounter% + 1
	if logCounter% > maxValue% then
		logCounter% = 0
	endif
	logCounter$ = StripLeadingSpaces(stri(logCounter%))

	while len(logCounter$) < numDigits%
		logCounter$ = "0" + logCounter$
	end while

	if writeToRegistry then
		m.bsp.WriteRegistrySetting("lc", logCounter$)
		m.bsp.registrySettings.logCounter$ = logCounter$
	else
		WriteAsciiFile("logCounter.txt", logCounter$)
	endif

	return logCounter$

End Function


Function CreateLogFile() As Object

    if not m.useDate then
		
		' don't use date for file name, use log counter
		logCounter$ = ReadAsciiFile("logCounter.txt")

		if logCounter$ = "" then
			logCounter$ = "000000"
		endif

		localFileName$ = "BrightSignLog." + m.deviceUniqueID$ + "-" + logCounter$ + ".log"

		fileNameLogCounter$ = logCounter$ 
		logCounter$ = m.UpdateLogCounter(logCounter$, 999999, 6, false)

	else

		' use date for file name

		logCounter$ = m.bsp.registrySettings.logCounter$

		dtLocal = m.systemTime.GetLocalDateTime()
		year$ = Right(stri(dtLocal.GetYear()), 2)
		month$ = StripLeadingSpaces(stri(dtLocal.GetMonth()))
		if len(month$) = 1 then
			month$ = "0" + month$
		endif
		day$ = StripLeadingSpaces(stri(dtLocal.GetDay()))
		if len(day$) = 1 then
			day$ = "0" + day$
		endif
		dateString$ = year$ + month$ + day$
    
		logDate$ = m.bsp.registrySettings.logDate$
    
		if logDate$ = "" or logCounter$ = "" then
			logCounter$ = "000"
		else if logDate$ <> dateString$ then
			logCounter$ = "000"
		endif
		logDate$ = dateString$
    
		localFileName$ = "BrightSign" + "Log." + m.deviceUniqueID$ + "-" + dateString$ + logCounter$ + ".log"

		m.bsp.WriteRegistrySetting("ld", logDate$)
		m.bsp.registrySettings.logDate$ = logDate$
    
		logCounter$ = m.UpdateLogCounter(logCounter$, 999, 3, true)

	endif

    fileName$ = "currentLog/" + localFileName$
    logFile = CreateObject("roCreateFile", fileName$)
    m.diagnostics.PrintDebug("Create new log file " + localFileName$)
    
    t$ = chr(9)
    
    ' version
    header$ = "BrightSignLogVersion"+t$+"3"
    logFile.SendLine(header$)
    
    ' serial number
    header$ = "SerialNumber"+t$+m.deviceUniqueID$
    logFile.SendLine(header$)
    
	' log counter
    if not m.useDate then
		counterInHeader$ = "LogCounter" + t$ + fileNameLogCounter$
		logFile.SendLine(counterInHeader$)
	endif

    ' group id
    if type(m.networking) = "roAssociativeArray" then
		if type(m.networking.currentSync) = "roSyncSpec" then
			header$ = "Account"+t$+m.networking.currentSync.LookupMetadata("server", "account")
			logFile.SendLine(header$)
			header$ = "Group"+t$+m.networking.currentSync.LookupMetadata("server", "group")
			logFile.SendLine(header$)
		endif
    endif
    
    ' timezone
    header$ = "Timezone"+t$+m.systemTime.GetTimeZone()
    logFile.SendLine(header$)

    ' timestamp of log creation
    header$ = "LogCreationTime"+t$+m.systemTime.GetLocalDateTime().GetString()
    logFile.SendLine(header$)
    
    ' ip address
    nc = CreateObject("roNetworkConfiguration", 0)
    if type(nc) = "roNetworkConfiguration" then
        currentConfig = nc.GetCurrentConfig()
        nc = invalid
        ipAddress$ = currentConfig.ip4_address
        header$ = "IPAddress"+t$+ipAddress$
        logFile.SendLine(header$)
    endif
    
    ' fw version
    header$ = "FWVersion"+t$+m.firmwareVersion$
    logFile.SendLine(header$)
    
    ' script version
    header$ = "ScriptVersion"+t$+m.autorunVersion$
    logFile.SendLine(header$)

    ' custom script version
    header$ = "CustomScriptVersion"+t$+m.customAutorunVersion$
    logFile.SendLine(header$)

    ' model
    header$ = "Model"+t$+m.deviceModel$
    logFile.SendLine(header$)

    logFile.AsyncFlush()
    
    return logFile
    
End Function


Sub MoveExpiredCurrentLog()

    dtLocal = m.systemTime.GetLocalDateTime()
    currentDate$ = StripLeadingSpaces(stri(dtLocal.GetDay()))
    if len(currentDate$) = 1 then
        currentDate$ = "0" + currentDate$
    endif

    listOfPendingLogFiles = MatchFiles("/currentLog", "*")
        
    for each file in listOfPendingLogFiles
    
        logFileDate$ = left(right(file, 9), 2)
    
        if logFileDate$ <> currentDate$ then
            sourceFilePath$ = "currentLog/" + file
            destinationFilePath$ = "logs/" + file
            CopyFile(sourceFilePath$, destinationFilePath$)
            DeleteFile(sourceFilePath$)
        endif
        
    next

End Sub


Sub MoveCurrentLog()

    listOfPendingLogFiles = MatchFiles("/currentLog", "*")
    for each file in listOfPendingLogFiles
        sourceFilePath$ = "currentLog/" + file
        destinationFilePath$ = "logs/" + file
        CopyFile(sourceFilePath$, destinationFilePath$)
        DeleteFile(sourceFilePath$)
    next
    
End Sub


Sub InitializeLogging(playbackLoggingEnabled As Boolean, eventLoggingEnabled As Boolean, stateLoggingEnabled As Boolean, diagnosticLoggingEnabled As Boolean, uploadLogFilesAtBoot As Boolean, uploadLogFilesAtSpecificTime As Boolean, uploadLogFilesTime% As Integer)

    m.loggingEnabled = playbackLoggingEnabled or eventLoggingEnabled or stateLoggingEnabled or diagnosticLoggingEnabled

	if m.loggingEnabled then
	    CreateDirectory("logs")
		CreateDirectory("currentLog")
		CreateDirectory("archivedLogs")
		CreateDirectory("failedLogs")
	endif
	     
    m.DeleteExpiredFiles()
    
    m.playbackLoggingEnabled = playbackLoggingEnabled
    m.eventLoggingEnabled = eventLoggingEnabled
    m.stateLoggingEnabled = stateLoggingEnabled
    m.diagnosticLoggingEnabled = diagnosticLoggingEnabled
    m.uploadLogFilesAtBoot = uploadLogFilesAtBoot
    m.uploadLogFilesAtSpecificTime = uploadLogFilesAtSpecificTime
    m.uploadLogFilesTime% = uploadLogFilesTime%

    m.uploadLogsEnabled = uploadLogFilesAtBoot or uploadLogFilesAtSpecificTime  

    if m.uploadLogFilesAtBoot then
        m.PushLogFilesOnBoot()
    endif
    
    m.MoveExpiredCurrentLog()

    if m.loggingEnabled then m.OpenOrCreateCurrentLog()
    
    m.InitializeCutoverTimer()
    
End Sub


Sub ReinitializeLogging(playbackLoggingEnabled As Boolean, eventLoggingEnabled As Boolean, stateLoggingEnabled As Boolean, diagnosticLoggingEnabled As Boolean, uploadLogFilesAtBoot As Boolean, uploadLogFilesAtSpecificTime As Boolean, uploadLogFilesTime% As Integer)

    if playbackLoggingEnabled = m.playbackLoggingEnabled and eventLoggingEnabled = m.eventLoggingEnabled and stateLoggingEnabled = m.stateLoggingEnabled and diagnosticLoggingEnabled = m.diagnosticLoggingEnabled and uploadLogFilesAtBoot = m.uploadLogFilesAtBoot and uploadLogFilesAtSpecificTime = m.uploadLogFilesAtSpecificTime and uploadLogFilesTime% = m.uploadLogFilesTime% then return
    
    m.loggingEnabled = playbackLoggingEnabled or eventLoggingEnabled or stateLoggingEnabled or diagnosticLoggingEnabled

	if m.loggingEnabled then
	    CreateDirectory("logs")
		CreateDirectory("currentLog")
		CreateDirectory("archivedLogs")
		CreateDirectory("failedLogs")
	endif
	     
    if type(m.cutoverTimer) = "roTimer" then
        m.cutoverTimer.Stop()
        m.cutoverTimer = invalid
    endif

    m.playbackLoggingEnabled = playbackLoggingEnabled
    m.eventLoggingEnabled = eventLoggingEnabled
    m.stateLoggingEnabled = stateLoggingEnabled
    m.diagnosticLoggingEnabled = diagnosticLoggingEnabled
    m.uploadLogFilesAtBoot = uploadLogFilesAtBoot
    m.uploadLogFilesAtSpecificTime = uploadLogFilesAtSpecificTime
    m.uploadLogFilesTime% = uploadLogFilesTime%

    m.uploadLogsEnabled = uploadLogFilesAtBoot or uploadLogFilesAtSpecificTime  

    if type(m.logFile) <> "roCreateFile" and type(m.logFile) <> "roAppendFile" and m.loggingEnabled then
        m.OpenOrCreateCurrentLog()
    endif
            
    m.InitializeCutoverTimer()

End Sub


Sub InitializeCutoverTimer()

    if m.uploadLogFilesAtSpecificTime then
        hour% = m.uploadLogFilesTime% / 60
        minute% = m.uploadLogFilesTime% - (hour% * 60)
    else
        hour% = 0
        minute% = 0
    endif
    
    m.cutoverTimer = CreateObject("roTimer")
    m.cutoverTimer.SetPort(m.msgPort)
    m.cutoverTimer.SetDate(-1, -1, -1)
    m.cutoverTimer.SetTime(hour%, minute%, 0)
    m.cutoverTimer.Start()    
    
End Sub


Function CopyAllLogFiles(storagePath$ As String) As Boolean

    if type(m.logFile) = "roCreateFile" or type(m.logFile) = "roAppendFile" then
	    m.logFile.Flush()
	endif

	ok = m.CopyLogFiles(storagePath$, "currentLog")
	if not ok return ok
	
	ok = m.CopyLogFiles(storagePath$, "logs")
	if not ok return ok
	
	ok = m.CopyLogFiles(storagePath$, "failedLogs")
	if not ok return ok

	ok = m.CopyLogFiles(storagePath$, "archivedLogs")
	return ok

End Function


Function CopyLogFiles(storagePath$ As String, folderName$ As String)

    listOfLogFiles = MatchFiles("/" + folderName$, "*")
        
    for each file in listOfLogFiles
        sourceFilePath$ = "/" + folderName$ + "/" + file
		destinationFilePath$ = storagePath$ + file
		ok = CopyFile(sourceFilePath$, destinationFilePath$)
		if not ok return ok
    next

	return true

End Function


Sub DeleteAllLogFiles()

	' close the current log file before deleting

    if type(m.logFile) = "roCreateFile" or type(m.logFile) = "roAppendFile" then
	    m.logFile.Flush()
		m.logFile = invalid
	endif

	m.DeleteLogFiles("currentLog")
	m.DeleteLogFiles("logs")
	m.DeleteLogFiles("failedLogs")
	m.DeleteLogFiles("archivedLogs")

End Sub


Sub DeleteLogFiles(folderName$ As String)

    listOfLogFiles = MatchFiles("/" + folderName$, "*")
        
    for each file in listOfLogFiles
        fullFilePath$ = "/" + folderName$ + "/" + file
		DeleteFile(fullFilePath$)
    next

End Sub


Sub DeleteExpiredFiles()

	if m.useDate then

		' delete any files that are more than 10 days old
    
		dtExpired = m.systemTime.GetLocalDateTime()
		dtExpired.SubtractSeconds(60 * 60 * 24 * 10)
    
		' look in the following folders
		'   logs
		'   failedLogs
		'   archivedLogs
    
		m.DeleteOlderFiles("logs", dtExpired)
		m.DeleteOlderFiles("failedLogs", dtExpired)
		m.DeleteOlderFiles("archivedLogs", dtExpired)
    
	else

		MAX_FILES_TO_KEEP = 60

		' get a list of all log files
		logFiles = CreateObject("roArray", 1, true)
		m.GetLogFiles("logs", logFiles)
		m.GetLogFiles("failedLogs", logFiles)
		m.GetLogFiles("archivedLogs", logFiles)

		' sort them in ascending order
		sortedIndices = CreateObject("roArray", 1, true)
		SortItems(logFiles, sortedIndices)

		' if the count is > than the number to keep, delete the first n in the list
		while sortedIndices.Count() > MAX_FILES_TO_KEEP

			fullFilePath$ = logFiles[sortedIndices[0]].fullFilePath$
            m.diagnostics.PrintDebug("Delete log file " + fullFilePath$)
            DeleteFile(fullFilePath$)
			
			sortedIndices.shift()

		endwhile

	endif

End Sub


' sorted indices is an array that can grow and has no values on entry
' items is an array of associative arrays
Sub SortItems(logFiles As Object, sortedIndices As Object)

    ' initialize array with indices.
    for i% = 0 to logFiles.Count()-1
        sortedIndices[i%] = i%
    next

    numItemsToSort% = logFiles.Count()

    for i% = numItemsToSort% - 1 to 1 step -1
        for j% = 0 to i%-1
	        index0% = sortedIndices[j%]
	        logCounter0% = logFiles[index0%].counter%
            index1% = sortedIndices[j%+1]
            logCounter1% = logFiles[index1%].counter%
            if logCounter0% > logCounter1% then
                k% = sortedIndices[j%]
                sortedIndices[j%] = sortedIndices[j%+1]
                sortedIndices[j%+1] = k%
            endif
        next
    next
    
End Sub


Sub GetLogFiles(folderName$ As String, logFiles As Object)

    listOfLogFiles = MatchFiles("/" + folderName$, "*")

    for each file in listOfLogFiles
		logFile = { }
		logFile.counter% = int(val(left(right(file, 7), 3)))
		logFile.fullFilePath$ = "/" + folderName$ + "/" + file
		logFiles.push(logFile)
	next

End Sub


Sub DeleteOlderFiles(folderName$ As String, dtExpired As Object)

    listOfLogFiles = MatchFiles("/" + folderName$, "*")
        
    for each file in listOfLogFiles
    
        year$ = "20" + left(right(file,13), 2)
        month$ = left(right(file,11), 2)
        day$ = left(right(file, 9), 2)
        dtFile = CreateObject("roDateTime")
        dtFile.SetYear(int(val(year$)))
        dtFile.SetMonth(int(val(month$)))
        dtFile.SetDay(int(val(day$)))
               
        if dtFile < dtExpired then
            fullFilePath$ = "/" + folderName$ + "/" + file
            m.diagnostics.PrintDebug("Delete expired log file " + fullFilePath$)
            DeleteFile(fullFilePath$)
        endif
        
    next

End Sub


Sub FlushLogFile()

    if type(m.logFile) <> "roCreateFile" and type(m.logFile) <> "roAppendFile" then return

    m.logFile.Flush()

End Sub


Sub WritePlaybackLogEntry(zoneName$ As String, startTime$ As String, endTime$ As String, itemType$ As String, fileName$ As String)

    if not m.playbackLoggingEnabled then return
    
    if type(m.logFile) <> "roCreateFile" and type(m.logFile) <> "roAppendFile" then return

    t$ = chr(9) 
    m.logFile.SendLine("L=p"+t$+"Z="+zoneName$+t$+"S="+startTime$+t$+"E="+endTime$+t$+"I="+itemType$+t$+"N="+fileName$)
    m.logFile.AsyncFlush()

End Sub


Sub WriteStateLogEntry(stateMachine As Object, stateName$ As String, stateType$ As String)

    if not m.stateLoggingEnabled then return

    if type(m.logFile) <> "roCreateFile" and type(m.logFile) <> "roAppendFile" then return

    timestamp$ = m.systemTime.GetLocalDateTime().GetString()

    t$ = chr(9) 

	if type(stateMachine.lastStateName$) = "roString" then
		lastStateName$ = stateMachine.lastStateName$
		lastEventType$ = stateMachine.lastEventType$
		lastEventData$ = stateMachine.lastEventData$
	else
		lastStateName$ = ""
		lastEventType$ = ""
		lastEventData$ = ""
	endif

    m.logFile.SendLine("L=s"+t$+"S="+stateName$+t$+"T="+timestamp$+t$+"Y="+stateType$+t$+"LS="+lastStateName$+t$+"LE="+lastEventType$+t$+"LD="+lastEventData$)
    m.logFile.AsyncFlush()

End Sub


Sub WriteEventLogEntry(stateMachine As Object, stateName$ As String, eventType$ As String, eventData$ As String, eventActedOn$ As String)

    if not (m.eventLoggingEnabled or m.stateLoggingEnabled) then return

    if type(m.logFile) <> "roCreateFile" and type(m.logFile) <> "roAppendFile" then return

    timestamp$ = m.systemTime.GetLocalDateTime().GetString()

	if eventActedOn$ = "1" then
		stateMachine.lastStateName$ = stateName$
		stateMachine.lastEventType$ = eventType$
		stateMachine.lastEventData$ = eventData$
	endif

	if m.eventLoggingEnabled then
		t$ = chr(9) 
		m.logFile.SendLine("L=e"+t$+"S="+stateName$+t$+"T="+timestamp$+t$+"E="+eventType$+t$+"D="+eventData$+t$+"A="+eventActedOn$)
		m.logFile.AsyncFlush()
	endif

End Sub


Sub WriteDiagnosticLogEntry(eventId$ As String, eventData$ As String)

    if not m.diagnosticLoggingEnabled then return

    if type(m.logFile) <> "roCreateFile" and type(m.logFile) <> "roAppendFile" then return

    timestamp$ = m.systemTime.GetLocalDateTime().GetString()
    
    t$ = chr(9) 
    m.logFile.SendLine("L=d"+t$+"T="+timestamp$+t$+"I="+eventId$+t$+"D="+eventData$)
    m.logFile.AsyncFlush()
    
End Sub


Sub PushLogFile(forceUpload As Boolean)

	if type(m.networking) <> "roAssociativeArray" then return

    if not m.uploadLogsEnabled and not forceUpload then return
    
' files that failed to upload in the past were moved to a different folder. move them back to the appropriate folder so that the script can attempt to upload them again
    listOfFailedLogFiles = MatchFiles("/" + m.uploadLogFailedFolder, "*.log")
    for each file in listOfFailedLogFiles
        target$ = m.uploadLogFolder + "/" + file
        fullFilePath$ = m.uploadLogFailedFolder + "/" + file
        ok = MoveFile(fullFilePath$, target$)
    next

    m.networking.UploadLogFiles()
    
End Sub


Sub PushLogFilesOnBoot()

    m.MoveCurrentLog()
    m.PushLogFile(false)

End Sub


Sub HandleLoggingTimerEvent()

    m.CutoverLogFile(false)

    m.cutoverTimer.Start()

End Sub


Sub CutoverLogFile(forceUpload As Boolean)

    if type(m.logFile) <> "roCreateFile" and type(m.logFile) <> "roAppendFile" then return

    m.logFile.Flush()
    m.MoveCurrentLog()
    m.logFile = m.CreateLogFile()

	if forceUpload or m.uploadLogFilesAtSpecificTime then
		m.PushLogFile(forceUpload)
	endif
    
    m.DeleteExpiredFiles()

End Sub


Sub OpenOrCreateCurrentLog()

' if there is an existing log file for today, just append to it. otherwise, create a new one to use

    listOfPendingLogFiles = MatchFiles("/currentLog", "*")
    
    for each file in listOfPendingLogFiles
        fileName$ = "currentLog/" + file
        m.logFile = CreateObject("roAppendFile", fileName$)
        if type(m.logFile) = "roAppendFile" then
            m.diagnostics.PrintDebug("Use existing log file " + file)
            return
        endif
    next

    m.logFile = m.CreateLogFile()
    
End Sub

'endregion

'region Hierarchical State Machine
' *************************************************
'
' Hierarchical State Machine Implementation
'
' *************************************************
Function newHSM() As Object

    HSM = CreateObject("roAssociativeArray")
    
    HSM.Initialize = HSMInitialize
	HSM.Constructor = HSMConstructor
    HSM.Dispatch = HSMDispatch
    HSM.IsIn = HSMIsIn
    
    HSM.InitialPseudostateHandler = invalid
	HSM.ConstructorHandler = invalid

    HSM.newHState = newHState
    HSM.topState = invalid
    HSM.activeState = invalid
    
    return HSM
    
End Function


Sub HSMConstructor()

	if type(m.ConstructorHandler) = invalid then stop

	m.ConstructorHandler()

End Sub


Sub HSMInitialize()

' there is definitely some confusion here about the usage of both activeState and m.activeState

    stateData = CreateObject("roAssociativeArray")
    
' empty event used to get super states
    emptyEvent = CreateObject("roAssociativeArray")
    emptyEvent["EventType"] = "EMPTY_SIGNAL"
    
' entry event 
    entryEvent = CreateObject("roAssociativeArray")
    entryEvent["EventType"] = "ENTRY_SIGNAL"

' init event
    initEvent = CreateObject("roAssociativeArray")
    initEvent["EventType"] = "INIT_SIGNAL"  

' execute initial transition     
	m.activeState = m.InitialPseudoStateHandler()
	
' if there is no activeState, the playlist is empty
	if type(m.activeState) <> "roAssociativeArray" return
	
	activeState = m.activeState
	    
' start at the top state
    if type(m.topState) <> "roAssociativeArray" then stop
    sourceState = m.topState
    
    while true
    
        entryStates = CreateObject("roArray", 4, true)
        entryStateIndex% = 0
        
        entryStates[0] = activeState                                            ' target of the initial transition
                
        status$ = m.activeState.HStateEventHandler(emptyEvent, stateData)       ' send an empty event to get the super state
        activeState = stateData.nextState
        m.activeState = stateData.nextState

        while (activeState.id$ <> sourceState.id$)                              ' walk up the tree until the current source state is hit
            entryStateIndex% = entryStateIndex% + 1
            entryStates[entryStateIndex%] = activeState
            status$ = m.activeState.HStateEventHandler(emptyEvent, stateData)
            activeState = stateData.nextState
            m.activeState = stateData.nextState
        end while
        
'        activeState = entryStates[0]                                           ' restore the target of the initial transition
        
        while (entryStateIndex% >= 0)                                           ' retrace the entry path in reverse (desired) order
            entryState = entryStates[entryStateIndex%]
            status$ = entryState.HStateEventHandler(entryEvent, stateData)
            entryStateIndex% = entryStateIndex% - 1
        end while

        sourceState = entryStates[0]                                            ' new source state is the current state
        
        status$ = sourceState.HStateEventHandler(initEvent, stateData)
        if status$ <> "TRANSITION" then
            m.activeState = sourceState
            return
        endif

        activeState = stateData.nextState        
        m.activeState = stateData.nextState
        
    end while

End Sub


Sub HSMDispatch(event As Object)

' if there is no activeState, the playlist is empty
	if type(m.activeState) <> "roAssociativeArray" return

    stateData = CreateObject("roAssociativeArray")
    
' empty event used to get super states
    emptyEvent = CreateObject("roAssociativeArray")
    emptyEvent["EventType"] = "EMPTY_SIGNAL"
    
' entry event 
    entryEvent = CreateObject("roAssociativeArray")
    entryEvent["EventType"] = "ENTRY_SIGNAL"

' exit event 
    exitEvent = CreateObject("roAssociativeArray")
    exitEvent["EventType"] = "EXIT_SIGNAL"

' init event
    initEvent = CreateObject("roAssociativeArray")
    initEvent["EventType"] = "INIT_SIGNAL"  
     
    t = m.activeState                                                       ' save the current state
    
    status$ = "SUPER"
    while (status$ = "SUPER")                                               ' process the event hierarchically
        s = m.activeState
        status$ = s.HStateEventHandler(event, stateData)
        m.activeState = stateData.nextState
'if type(m.activeState) = "roAssociativeArray" then
'    print "m.activeState set to " + m.activeState.id$ + "0"        
'else
'    print "m.activeState set to invalid 0"
'endif
    end while
    
    if (status$ = "TRANSITION")
        path = CreateObject("roArray", 4, true)
        
        path[0] = m.activeState                                             ' save the target of the transition
        path[1] = t                                                         ' save the current state
        
        while (t.id$ <> s.id$)                                              ' exit from the current state to the transition s
            status$ = t.HStateEventHandler(exitEvent, stateData)
            if status$ = "HANDLED" then
                status$ = t.HStateEventHandler(emptyEvent, stateData)
            endif
            t = stateData.nextState
        end while
        
        t = path[0]                                                         ' target of the transition
        
        ' s is the source of the transition
        
        if (s.id$ = t.id$) then                                             ' check source == target (transition to self)
            status$ = s.HStateEventHandler(exitEvent, stateData)            ' exit the source
            ip = 0
        else
            status$ = t.HStateEventHandler(emptyEvent, stateData)           ' superstate of target
            t = stateData.nextState
            if (s.id$ = t.id$) then                                         ' check source == target->super
                ip = 0                                                      ' enter the target
            else
                status$ = s.HStateEventHandler(emptyEvent, stateData)       ' superstate of source
                if (stateData.nextState.id$ = t.id$) then                   ' check source->super == target->super
                    status$ = s.HStateEventHandler(exitEvent, stateData)    ' exit the source
                    ip = 0                                                  ' enter the target
                else
                    if (stateData.nextState.id$ = path[0].id$) then         ' check source->super == target
                        status$ = s.HStateEventHandler(exitEvent, stateData)     ' exit the source
                    else                                                    ' check rest of source == target->super->super and store the entry path along the way
                        iq = 0                                              ' indicate LCA not found
                        ip = 1                                              ' enter target and its superstate
                        path[1] = t                                         ' save the superstate of the target
                        t = stateData.nextState                             ' save source->super
                                                                            ' get target->super->super
                        status$ = path[1].HStateEventHandler(emptyEvent, stateData)
                        while (status$ = "SUPER")
                             ip = ip + 1
                             path[ip] = stateData.nextState                 ' store the entry path
                             if (stateData.nextState.id$ = s.id$) then      ' is it the source?
                                iq = 1                                      ' indicate that LCA found
                                ip = ip - 1                                 ' do not enter the source
                                status$ = "HANDLED"                         ' terminate the loop
                             else                                           ' it is not the source; keep going up
                                status$ = stateData.nextState.HStateEventHandler(emptyEvent, stateData)
                             endif
                        end while
                    
                        if (iq = 0) then                                    ' LCA not found yet
                            status$ = s.HStateEventHandler(exitEvent, stateData) ' exit the source
                            
                                                                            ' check the rest of source->super == target->super->super...
                            iq = ip
                            status = "IGNORED"                              ' indicate LCA not found
                            while (iq >= 0)
                                if (t.id$ = path[iq].id$) then              ' is this the LCA?
                                    status = "HANDLED"                      ' indicate LCA found
                                    ip = iq - 1                             ' do not enter LCA
                                    iq = -1                                 ' terminate the loop
                                else
                                    iq = iq -1                              ' try lower superstate of target
                                endif
                            end while
                            
                            if (status <> "HANDLED") then                   ' LCA not found yet?
                            
                                                                            ' check each source->super->... for each target->super...
                                status = "IGNORED"                          ' keep looping
                                while (status <> "HANDLED")
                                    status$ = t.HStateEventHandler(exitEvent, stateData)
                                    if (status$ = "HANDLED") then
                                        status$ = t.HStateEventHandler(emptyEvent, stateData)
                                    endif
                                    t = stateData.nextState                 ' set to super of t
                                    iq = ip
                                    while (iq > 0)
                                        if (t.id$ = path[iq].id$) then      ' is this the LCA?
                                            ip = iq - 1                     ' do not enter LCA
                                            iq = -1                         ' break inner
                                            status = "HANDLED"              ' break outer
                                        else
                                            iq = iq - 1
                                        endif
                                    end while
                                end while
                            endif
                        endif
                    endif
                endif
            endif
        endif
        
        ' retrace the entry path in reverse (desired) order...
        while (ip >= 0)
            status$ = path[ip].HStateEventHandler(entryEvent, stateData)    ' enter path[ip]
            ip = ip - 1
        end while
        
        t = path[0]                                                         ' stick the target into register */
        m.activeState = t                                                   ' update the current state */
'print "m.activeState set to " + m.activeState.id$ + "1"        


        ' drill into the target hierarchy...
        status$ = t.HStateEventHandler(initEvent, stateData)
        m.activeState = stateData.nextState
        while (status$ = "TRANSITION")
' stop            
            ip = 0
            path[0] = m.activeState
            status$ = m.activeState.HStateEventHandler(emptyEvent, stateData)            ' find superstate
            m.activeState = stateData.nextState
'print "m.activeState set to " + m.activeState.id$ + "2"        
            while (m.activeState.id$ <> t.id$)
                ip = ip + 1
                path[ip] = m.activeState
                status$ = m.activeState.HStateEventHandler(emptyEvent, stateData)        ' find superstate
                m.activeState = stateData.nextState
'print "m.activeState set to " + m.activeState.id$ + "3"        
            end while
            m.activeState = path[0]
'print "m.activeState set to " + m.activeState.id$ + "4"        
            
            while (ip >= 0)
                status$ = path[ip].HStateEventHandler(entryEvent, stateData)
                ip = ip - 1
            end while
            
            t = path[0]
            
            status$ = t.HStateEventHandler(initEvent, stateData)

        end while
        
    endif
    
    m.activeState = t   ' set the new state or restore the current state
'print "m.activeState set to " + m.activeState.id$ + "5"        
    
End Sub


Function HSMIsIn() As Boolean

    return false

End Function


Function newHState(bsp As Object, id$ As String) As Object

    HState = CreateObject("roAssociativeArray")
    
    HState.HStateEventHandler = invalid         ' filled in by HState instance
    
    HState.stateMachine = m
    HState.bsp = bsp
    
    HState.superState = invalid                 ' filled in by HState instance
    HState.id$ = id$
    
    return HState
    
End Function

'endregion

'region Diagnostics
REM *******************************************************
REM *******************************************************
REM ***************                    ********************
REM *************** DIAGNOSTICS OBJECT ********************
REM ***************                    ********************
REM *******************************************************
REM *******************************************************
REM
REM construct a new diagnostics BrightScript object
REM
Function newDiagnostics(sysFlags As Object) As Object

    diagnostics = CreateObject("roAssociativeArray")
    
    diagnostics.debug = sysFlags.debugOn
    diagnostics.autorunVersion$ = "unknown"
    diagnostics.customAutorunVersion$ = "unknown"
    diagnostics.firmwareVersion$ = "unknown"
    diagnostics.systemTime = CreateObject("roSystemTime")
    
    diagnostics.systemLogDebug = sysFlags.systemLogDebugOn
    if diagnostics.systemLogDebug then
		diagnostics.systemLog = CreateObject("roSystemLog")
	endif
	
    diagnostics.UpdateDebugOn = UpdateDebugOn
    diagnostics.UpdateSystemLogDebugOn = UpdateSystemLogDebugOn
    diagnostics.PrintDebug = PrintDebug
    diagnostics.PrintTimestamp = PrintTimestamp
    diagnostics.SetSystemInfo = SetSystemInfo

    return diagnostics

End Function


Sub UpdateDebugOn(debugOn As Boolean)

    m.debug = debugOn

End Sub


Sub UpdateSystemLogDebugOn(systemLogDebug As Boolean)

    m.systemLogDebug = systemLogDebug
    
    if systemLogDebug and type(m.systemLog) <> "roSystemLog" then
		m.systemLog = CreateObject("roSystemLog")
    endif

End Sub


Sub PrintDebug(debugStr$ As String)

    if type(m) <> "roAssociativeArray" then stop
    
    if m.debug then 

        print debugStr$
        
    endif

    if m.systemLogDebug then
		m.systemLog.SendLine(debugStr$)
	endif
	
    return

End Sub


Sub PrintTimestamp()

    eventDateTime = m.systemTime.GetLocalDateTime()
    if m.debug then print eventDateTime.GetString()

    if m.systemLogDebug then
		m.systemLog.SendLine(eventDateTime.GetString())
	endif

    return

End Sub


Sub SetSystemInfo(sysInfo As Object, diagnosticCodes As Object)

    m.autorunVersion$ = sysInfo.autorunVersion$
    m.customAutorunVersion$ = sysInfo.customAutorunVersion$
    m.firmwareVersion$ = sysInfo.deviceFWVersion$
    m.deviceUniqueID$ = sysInfo.deviceUniqueID$
    m.deviceModel$ = sysInfo.deviceModel$
    m.deviceFamily$ = sysInfo.deviceFamily$
    m.modelSupportsWifi = sysInfo.modelSupportsWifi
    
    m.enableLogDeletion = sysInfo.enableLogDeletion
    
    m.diagnosticCodes = diagnosticCodes
    
    return

End Sub


Function GetColor(colorAttrs As Object) As Integer

    alpha$ = colorAttrs["a"]
    alpha% = val(alpha$)
    red$ = colorAttrs["r"]
    red% = val(red$)
    green$ = colorAttrs["g"]
    green% = val(green$)
    blue$ = colorAttrs["b"]
    blue% = val(blue$)
    
    color_spec% = (alpha%*256*256*256) + (red%*256*256) + (green%*256) + blue%
    return color_spec%

End Function


Function GetHexColor(colorAttrs As Object) As String

	ba = CreateObject("roByteArray")

	ba[0] = val(colorAttrs["a"])
	alpha$ = ba.ToHexString()

    ba[0] = val(colorAttrs["r"])
	red$ = ba.ToHexString()
	    
    ba[0] = val(colorAttrs["g"])
	green$ = ba.ToHexString()
	    
    ba[0] = val(colorAttrs["b"])
	blue$ = ba.ToHexString()
	    
	return alpha$ + red$ + green$ + blue$

End Function


Function ByteArraysMatch(baInput As Object, baSpec As Object) As Boolean

	if baSpec.Count() > baInput.Count() return false
	
	numBytesToMatch% = baSpec.Count()
	numBytesInInput% = baInput.Count()
	startByteInInput% = numBytesInInput% - numBytesToMatch%
	
	for i% = 0 to baSpec.Count() - 1
		if baInput[startByteInInput% + i%] <> baSpec[i%] return false
	next
		
	return true
	
End Function


Function StripLeadingSpaces(inputString$ As String) As String

    while true
        if left(inputString$, 1)<>" " then return inputString$
        inputString$ = right(inputString$, len(inputString$)-1)
    endwhile

    return inputString$

End Function


Function CopyDateTime(dateTimeIn As Object) As Object

    dateTimeOut = CreateObject("roDateTime")
    dateTimeOut.SetYear(dateTimeIn.GetYear())
    dateTimeOut.SetMonth(dateTimeIn.GetMonth())
    dateTimeOut.SetDay(dateTimeIn.GetDay())
    dateTimeOut.SetHour(dateTimeIn.GetHour())
    dateTimeOut.SetMinute(dateTimeIn.GetMinute())
    dateTimeOut.SetSecond(dateTimeIn.GetSecond())
    dateTimeOut.SetMillisecond(dateTimeIn.GetMillisecond())
    
    return dateTimeOut
    
End Function


REM *******************************************************
REM *******************************************************
REM ***************                    ********************
REM *************** DIAGNOSTIC CODES   ********************
REM ***************                    ********************
REM *******************************************************
REM *******************************************************

Function newDiagnosticCodes() As Object

    diagnosticCodes = CreateObject("roAssociativeArray")
    
    diagnosticCodes.EVENT_STARTUP                               = "1000"
    diagnosticCodes.EVENT_SYNCSPEC_RECEIVED                     = "1001"
    diagnosticCodes.EVENT_DOWNLOAD_START                        = "1002"
    diagnosticCodes.EVENT_FILE_DOWNLOAD_START                   = "1003"
    diagnosticCodes.EVENT_FILE_DOWNLOAD_COMPLETE                = "1004"
    diagnosticCodes.EVENT_DOWNLOAD_COMPLETE                     = "1005"
    diagnosticCodes.EVENT_READ_SYNCSPEC_FAILURE                 = "1006"
    diagnosticCodes.EVENT_RETRIEVE_SYNCSPEC_FAILURE             = "1007"
    diagnosticCodes.EVENT_NO_SYNCSPEC_AVAILABLE                 = "1008"
    diagnosticCodes.EVENT_SYNCSPEC_DOWNLOAD_IMMEDIATE_FAILURE   = "1009"
    diagnosticCodes.EVENT_FILE_DOWNLOAD_FAILURE                 = "1010"
    diagnosticCodes.EVENT_SYNCSPEC_DOWNLOAD_FAILURE             = "1011"
    diagnosticCodes.EVENT_SYNCPOOL_PROTECT_FAILURE              = "1012"
    diagnosticCodes.EVENT_LOGFILE_UPLOAD_FAILURE                = "1013"
    diagnosticCodes.EVENT_SYNC_ALREADY_ACTIVE                   = "1014"
    diagnosticCodes.EVENT_CHECK_CONTENT                         = "1015"
    diagnosticCodes.EVENT_FILE_DOWNLOAD_PROGRESS                = "1016"
    diagnosticCodes.EVENT_FIRMWARE_DOWNLOAD                     = "1017"
    diagnosticCodes.EVENT_SCRIPT_DOWNLOAD                       = "1018"
    diagnosticCodes.EVENT_BATTERY_STATUS						= "1019"
    diagnosticCodes.EVENT_POWER_EVENT							= "1020"
	diagnosticCodes.EVENT_USER_VARIABLE_NOT_FOUND				= "1021"
	diagnosticCodes.EVENT_MEDIA_COUNTER_VARIABLE_NOT_FOUND		= "1022"
	diagnosticCodes.EVENT_START_PRESENTATION					= "1023"
	diagnosticCodes.EVENT_GPS_LOCATION							= "1024"
	diagnosticCodes.EVENT_GPS_NOT_LOCKED						= "1025"
    diagnosticCodes.EVENT_RETRIEVE_USER_VARIABLE_FEED           = "1026"
    diagnosticCodes.EVENT_RETRIEVE_LIVE_TEXT_FEED				= "1027"
    diagnosticCodes.EVENT_USER_VARIABLE_FEED_DOWNLOAD_FAILURE   = "1028"
    diagnosticCodes.EVENT_LIVE_TEXT_FEED_DOWNLOAD_FAILURE		= "1029"
	diagnosticCodes.EVENT_UNASSIGNED_LOCAL_PLAYLIST				= "1030"
	diagnosticCodes.EVENT_UNASSIGNED_LOCAL_PLAYLIST_NO_NAVIGATION = "1031"
	diagnosticCodes.EVENT_REALIZE_FAILURE						= "1032"
    diagnosticCodes.EVENT_LIVE_TEXT_PLUGIN_FAILURE				= "1033"
    diagnosticCodes.EVENT_INVALID_DATE_TIME_SPEC				= "1034"
    diagnosticCodes.EVENT_HTML5_LOAD_ERROR						= "1035"
    diagnosticCodes.EVENT_USB_UPDATE_SECURITY_ERROR				= "1036"
    diagnosticCodes.EVENT_TUNE_FAILURE							= "1037"
    diagnosticCodes.EVENT_SCAN_START							= "1038"
    diagnosticCodes.EVENT_CHANNEL_FOUND							= "1039"
    diagnosticCodes.EVENT_SCAN_COMPLETE							= "1040"
    diagnosticCodes.EVENT_SCRIPT_PLUGIN_FAILURE					= "1041"
    diagnosticCodes.EVENT_BLC400_STATUS							= "1100"

    return diagnosticCodes
    
End Function

'endregion

'region GPS Functions
REM ==================================================
REM           GPS Functions
REM ==================================================
' Parse the NMEA GPRMC format and return the data in an object - http://www.gpsinformation.org/dale/nmea.htm
' The returned object contains the following fields
' .valid - boolean - is the sentence is correctly formed, has the correct checksum and has the correct GPRMC header
' .fixTime - contains the string from the sentence that is the time the sample was taken - no processing is done on this
' .fixActive - boolean - does the latitude and longitude contain real data
' .latitude - float - signed degrees of the latitude
' .longitude - float - signed degrees of the longitude
Sub ParseGPSdataGPRMCformat(NMEAsentence as string) as object
	gpsData = {}

	starLoc = instr(1, NMEAsentence, "*")
	if starLoc = 0 then
		gpsData.valid = false
	else if starLoc = len(NMEAsentence) - 2 then
		CalcChecksum = CalcChecksum (mid(NMEAsentence, 2, len(NMEAsentence)-4))
		ba=CreateObject("roByteArray")
		ba.fromhexstring(mid(NMEAsentence, len(NMEAsentence)-1, 2))
		CalcChecksum = ba[0]
		if (CalcChecksum <> CalcChecksum) then
			gpsData.valid = false
		else
			' Strip off the beginning $ sign and the * + checksum
			strippedSentence = mid(NMEAsentence, 2, len(NMEAsentence)-4)

			' Get the identifier
			field = getNextGPSfield(strippedSentence, 1)
			gpsData.type = field.fieldString
			
			' Make sure this is the right data format
			if (gpsData.type <> "GPRMC") then
				gpsData.valid = false
			else
				gpsData.valid = true

				' Get the fix time 
				field = getNextGPSfield(strippedSentence, field.nextFieldStart)
				gpsData.fixTime = field.fieldString

				' Get the status of the fix: A=Active, V=Void time, convert to fixActive = true for A, false for V
				field = getNextGPSfield(strippedSentence, field.nextFieldStart)
				if (field.fieldString <> "A") then
					gpsData.fixActive = false
					gpsData.latitude = 0
					gpsData.longitude = 0
				else
					gpsData.fixActive = true

					' Get the Latitude
					field = getNextGPSfield(strippedSentence, field.nextFieldStart)
					latDegrees = val(left(field.fieldString,2))
					latMinutes = val(mid(field.fieldString,3))
					latDegrees = latDegrees + (latMinutes/60)

					' Get the Latitude Direction
					field = getNextGPSfield(strippedSentence, field.nextFieldStart)
				
					' Adjust the sign of the angle based on the direction
					gpsData.latitude = ConvertNSEWtoQuadrant(field.fieldString, latDegrees)

					' Get the Longitude
					field = getNextGPSfield(strippedSentence, field.nextFieldStart)
					longDegrees = val(left(field.fieldString,3))
					longMinutes = val(mid(field.fieldString,4))
					longDegrees = longDegrees + (longMinutes/60)

					' Get the Longitude Direction
					field = getNextGPSfield(strippedSentence, field.nextFieldStart)
				
					' Adjust the sign of the angle based on the direction
					gpsData.longitude = ConvertNSEWtoQuadrant(field.fieldString, longDegrees)
				end if
			end if
		end if
	end if

	return gpsData
end Sub

' Parse and return the next NMEA field from the sentence
' returns an object with two members:
' .fieldString - contains the contents of the field, if nothing is in the field - returns ""
' .nextFieldStart - indicates the location in the string where the next field should start
Sub getNextGPSfield (NMEAsentence as string, startingIndex as integer) as object
	gpsField = {}
	' Look for the next field seperator as a comma (this is the case except for the checksum which is a *)
	fieldEndLoc = instr(startingIndex, NMEAsentence, ",")
	if fieldEndLoc <> 0 then
		if fieldEndLoc > startingIndex then
			gpsField.fieldString = mid(NMEAsentence, startingIndex, fieldEndLoc-startingIndex)
		else
			gpsField.fieldString = ""
		end if
		gpsField.nextFieldStart = fieldEndLoc + 1
	else
		stringLen = len(NMEAsentence)
		if (stringLen >= startingIndex) then
			gpsField.fieldString = mid(NMEAsentence, startingIndex, stringLen-startingIndex+1)
		else
			gpsField.fieldString = ""
		end if
		gpsField.nextFieldStart = stringLen + 1
	end if

	return (gpsField)
end Sub
		

' Calculate the great circle distance of two gps points - points must be in radians
Sub CalcGPSDistance(lat1 as float, lon1 as float, lat2 as float, lon2 as float)  as float

	radiusOfEarthInFeet# = 3963.1 * 5280.0
		
	' Convert coodinate 1 to Cartesian coordinates
	x1# = radiusOfEarthInFeet# * cos(lon1) * sin(lat1)
	y1# = radiusOfEarthInFeet# * sin(lon1) * sin(lat1)
	z1# = radiusOfEarthInFeet#  * sin(lat1)

	' Convert coodinate 2 to Cartesian coordinates
	x2# = radiusOfEarthInFeet# * cos(lon2) * sin(lat2)
	y2# = radiusOfEarthInFeet# * sin(lon2) * sin(lat2)
	z2# = radiusOfEarthInFeet#  * sin(lat2)

	' Calc the distance based on Euclidean distance
	distance = sqr((x1#-x2#)*(x1#-x2#) + (y1#-y2#)*(y1#-y2#) + (z1#-z2#)*(z1#-z2#))

	return (distance)
end sub


' Calculate the checksum based on the NMEA stardard - http://www.gpsinformation.org/dale/nmea.htm
' the checksum is an XOR of all characters between the $ and * in the sentence
Sub CalcChecksum (theString as string) as integer
	checksum = 0

	theStringLen = len (theString)
	if (theStringLen >= 2) then 
		a = asc(mid(theString,1,1))
		b = asc(mid(thestring,2,1))
		' XOR the two first two characters in the string
		checksum = &HFF AND ((a OR b) AND (NOT(a AND b)))
	else if (theStringLen = 1) then
		' If only one character is in the string, it is the checksum
		checksum = asc(mid(theString,1,1))
	end if
	if (theStringLen >= 3) then 
		for i= 3 to theStringLen
			a = checksum
			b = asc(mid(thestring,i,1))
			' XOR the current checksum with the next character
			checksum =  &HFF AND ((a OR b) AND (NOT(a AND b)))
		next
	end if

	return (checksum)
end sub


Sub ConvertDecimalDegtoRad(deg as float) as float
    pi = 3.14159265358979
	radians = deg * (pi/180)

	return (radians)
end Sub

Sub ConvertNSEWtoQuadrant(direction as string, angle as float) as float
	if (direction = "W") or (direction = "w") or (direction = "S") or (direction = "s") then
		angle = angle * -1
	end if

	return (angle)
end sub

'endregion

'region SIGNCHANNEL / MEDIARSS
REM *******************************************************
REM *******************************************************
REM ***************                         ***************
REM *************** SIGNCHANNEL / MEDIARSS  ***************
REM ***************                         ***************
REM *******************************************************
REM *******************************************************

REM ==================================================
REM           FeedPlayer Object
REM ==================================================
REM 
REM Top-level application object
REM   - manages Feed lifetime
REM   - contains EventLoop
REM
REM Owns top level image player, message port, event loop.
REM 
REM   - manages Feed object lifetimes
REM   - reaches into Feed object to get FeedItems to display
REM   - reaches into FeedItems to fetch supporting feedItem assets
REM 
Function newFeedPlayer(stateMachine As Object, imagePlayer As Object, videoPlayer As Object, msgPort As Object, videoDownloader As Object, loopMode As Object, rssURL$ As String, slideTransition% As Integer, diagnostics As Object, isDynamicPlaylist As Boolean, liveDataFeedUpdateInterval% As Integer) As Object
	fp = { name:"FeedPlayer" }
	fp.stateMachine				= stateMachine
	fp.feed						= Invalid
	fp.newFeed					= Invalid
	fp.currentItem				= Invalid
	fp.currentImageLoadItem		= Invalid
	fp.feedHost					= GetHost()
	fp.loadFailed				= FALSE
	fp.LOAD_SUCCESS				= 0
	fp.LOAD_TRANSFER_FAILURE	= 1
	fp.LOAD_INVALID_XML			= 2
	fp.LOAD_EMPTY_RSS			= 3
	fp.loadFailureReason		= fp.LOAD_SUCCESS
	fp.loadInProgress			= FALSE
	fp.lastLoadAttempt			= 0
	fp.lastItemPlayedWasVideo	= FALSE
	fp.cacheManager				= newCacheManager(diagnostics)
	fp.deviceInfo				= CreateObject("roDeviceInfo")
	fp.imageTimer				= CreateObject("roTimer")
	fp.imageRetryTimer			= CreateObject("roTimer")
	fp.feedTimer				= CreateObject("roTimer")

' adds
    fp.diagnostics          = diagnostics
    fp.reachedEnd           = FALSE
    fp.IsEnabled = true
    fp.InitialLoadComplete = false
    fp.loopMode = loopMode
    fp.rssURL$ = rssURL$
	fp.videoPlayer = videoPlayer
	if type(fp.videoPlayer) = "roVideoPlayer" then
		fp.videoPlayer.SetLoopMode(false)
    endif
' end of adds

	fp.endCycleEvent = CreateObject("roAssociativeArray")
	fp.endCycleEvent["EventType"] = "EndCycleEvent"

	fp.loadEvent = CreateObject("roAssociativeArray")
	fp.loadEvent["EventType"] = "LoadEvent"

	fp.FeedSwap = pFeedPlayer_FeedSwap

	fp.GetFeedURI = pFeedPlayer_GetFeedURI
    fp.mport = msgPort
    fp.imagePlayer = imagePlayer
	if type(fp.imagePlayer) = "roImageWidget" then
		fp.imagePlayer.SetDefaultTransition(slideTransition%)
	endif
	fp.slideTransition% = slideTransition%
	fp.isDynamicPlaylist = isDynamicPlaylist
	fp.liveDataFeedUpdateInterval% = liveDataFeedUpdateInterval%

    fp.videoDownloader = videoDownloader

	fp.imageTimer.SetPort(fp.mport)
	fp.imageRetryTimer.SetPort(fp.mport)
	fp.feedTimer.SetPort(fp.mport)

	fp.feedCacheDir = "/feed_cache/"
	CreateDirectory(fp.feedCacheDir)
	fp.feedCache = fp.feedCacheDir + "fmfeed.xml"

	fp.createTime       = fp.deviceInfo.GetDeviceUpTime()

	helper_FeedPlayerMethodInit( fp )

	return fp
End Function


Sub helper_FeedPlayerMethodInit( fp As Object ) 

	fp.HandleUrlEvent       = pFeedPlayer_HandleUrlEvent
	fp.HandleVideoEvent		= pFeedPlayer_HandleVideoEvent
	fp.HandleScriptEvent	= pfeedPlayer_HandleScriptEvent
	fp.PostSignChannelEndEvent	= pfeedPlayer_PostSignChannelEndEvent
	fp.FetchFeed            = pFeedPlayer_FetchFeed
	fp.FetchFeedNoAsync	    = pFeedPlayer_FetchFeedNoAsync
	fp.ParseFeed            = pFeedPlayer_ParseFeed
	fp.GetTime              = pFeedPlayer_GetTime
	fp.DisplayNextItem      = pFeedPlayer_DisplayNextItem
	fp.LoadNextItem		    = pFeedPlayer_LoadNextItem
	fp.SetFeed              = pFeedPlayer_SetFeed
	fp.DisplayItem          = pFeedPlayer_DisplayItem
	fp.HandleTimerEvent     = pFeedPlayer_HandleTimerEvent
	fp.GetURL               = pFeedPlayer_GetURL
	fp.LoadFeedFile         = pFeedPlayer_LoadFeedFile
	fp.PreloadItem		    = pfeedPlayer_preloadItem
	fp.systemTime           = CreateObject("roSystemTime")
	fp.AddSecsToTimer		= pFeedPlayer_AddSecsToTimer
	fp.PopulateFeedItems	= pFeedPlayer_PopulateFeedItems

	fp.model = fp.deviceInfo.GetModel()

End Sub


Function pFeedPlayer_GetTime() As Integer
	return m.deviceInfo.GetDeviceUptime()
End Function


REM ============================================
REM pFeedPlayer_HandleUrlEvent
REM ============================================
REM
REM Member in FeedPlayer object
REM
REM Callback handler for asynchronous RSS feed
REM download
REM 
REM If download successful new feed is parsed
REM and ( pending successful parse ) swapped in
REM as current feed.
REM
REM -------------------------------------------

Function pFeedPlayer_HandleUrlEvent( event As Object ) As void

    m.diagnostics.PrintDebug("FeedPlayer - URL EVENT" + stri(event.GetInt()))
    m.diagnostics.PrintDebug("URL EVENT CODE: " + stri(event.GetResponseCode()))
    m.diagnostics.PrintDebug("URL SOURCE: " + stri(event.GetSourceIdentity()))
	if type(m.feed) = "roAssociativeArray" m.diagnostics.PrintDebug("Image Downloader =" + stri(m.feed.imageDownloader.GetIdentity()))
    m.diagnostics.PrintDebug("Video Downloader = " + stri(m.videoDownloader.videoDownloader.GetIdentity()))
    m.diagnostics.PrintDebug("Feed transfer =" + stri(m.feedTransfer.GetIdentity()))

'	print "URL EVENT "; event
'	print "URL EVENT CODE: ";event.GetResponseCode()
'	print "URL EVENT STATUS: ";event.GetInt()
'	print "URL SOURCE";event.GetSourceIdentity()
'	if type(m.feed) = "roAssociativeArray" print "Image Downloader =";m.feed.imageDownloader.GetIdentity()
'	print "Video Downloader =";m.videoDownloader.videoDownloader.GetIdentity()
'	print "Feed transfer =";m.feedTransfer.GetIdentity()

	eventId = event.GetSourceIdentity()
	eventCode = event.GetResponseCode()
	eventStatus = event.GetInt()

	if type(m.feed) = "roAssociativeArray" and eventId = m.feed.imageDownloader.GetIdentity() then
		REM This is an event from downloading an image			
	    m.diagnostics.PrintDebug("URL - DOWNLOAD IMAGE")
		if eventStatus = 2 then
		    m.diagnostics.PrintDebug("DOWNLOAD in PROGRESS")
		else if eventStatus = 1 then
			if (eventCode <> 200) then
			    m.diagnostics.PrintDebug("ERROR on downloading IMAGE item ERROR Code:" + stri(eventCode))
				m.feed.asyncImageDownloadInProgress = false
				if not m.feed.atLoadEnd then
					m.LoadNextItem()
				end if
			else
				m.diagnostics.PrintDebug("DOWNLOAD COMPLETE")

				' track download traffic for dynamic playlists
				if m.isDynamicPlaylist and type(m.stateMachine.bsp.networkingHSM) = "roAssociativeArray" then
					fname = m.feed.imageDownloader.GetUserData()
					checkFile = CreateObject("roReadFile", fname)
					if (checkFile <> invalid) then
						checkFile.SeekToEnd()
						size = checkFile.CurrentPosition()
						checkFile = invalid
						m.stateMachine.bsp.networkingHSM.UploadMRSSTrafficDownload(size)
					endif
				endif

				m.feed.asyncImageDownloadInProgress = false
				m.currentImageLoadItem.downloaded = true
				if not m.feed.atLoadEnd then
					m.LoadNextItem()
				end if
			end if
		else
			m.diagnostics.PrintDebug("UKNOWN Status code:" + stri(eventStatus))
		end if
	else if eventId = m.feedTransfer.GetIdentity() then
		m.diagnostics.PrintDebug("URL - FEED TRANSFER")
		If event.GetInt() = 2 then
			REM load still in progress
		else 
			m.loadInProgress = FALSE
			eventCode = event.GetResponseCode()
			if eventCode <> 200 then
				m.diagnostics.PrintDebug("Feed Transfer Failed - bad response code:" + stri(eventCode))
				m.LoadFailed = TRUE
				m.LoadFailureReason = m.LOAD_TRANSFER_FAILURE
			else if not m.LoadFeedFile() then
				m.diagnostics.PrintDebug("Failed to load the feed from the transferred file")
			else
				m.diagnostics.PrintDebug("Transferred and loaded the feed file sucessfully")
			end If
		end if
	endif
 
End Function


Function pfeedPlayer_HandleScriptEvent( event As Object ) As void

	if type(event["EventType"]) = "roString" then
		if event["EventType"] = "EndCycleEvent" then
			m.diagnostics.PrintDebug("********************** End of Cycle Event ****************")
			if m.newFeed <> Invalid Then
				m.feedSwap()
			else
				m.diagnostics.PrintDebug("No new feed available")
			end if 
		else if event["EventType"] = "LoadEvent" then
			m.diagnostics.PrintDebug("********************** Load Event ****************")
			if not m.feed.atLoadEnd then 
				m.diagnostics.PrintDebug("********************** Load next item ****************")
				m.LoadNextItem()
			else
				m.diagnostics.PrintDebug("********************** At load end, not loading anymore ****************")
			end if
		else 
			m.diagnostics.PrintDebug("********************** Unexpected Script Event:" + event["EventType"])
		end if
	else
		m.diagnostics.PrintDebug("********************** Unexpected Event type:" + type(event["EventType"]))
	end if
End Function


Sub pfeedPlayer_PostSignChannelEndEvent()

    if not m.loopMode then
        m.diagnostics.PrintDebug("Post end of feed message")
        endOfFeed = CreateObject("roAssociativeArray")
        endOfFeed["EventType"] = "SignChannelEndEvent"
        m.mport.PostMessage(endOfFeed)
        m.IsEnabled = false
    endif
    
End Sub


Function pFeedPlayer_LoadFeedFile() As Boolean
    m.diagnostics.PrintDebug("Loading from cache=" + m.feedCache)
	m.loadFailureReason = m.LOAD_SUCCESS
	text = ReadAsciiFile(m.feedCache)
	feed = m.ParseFeed( text )
	If feed = Invalid then
        m.diagnostics.PrintDebug("Feed Parse Failed")
		m.loadFailed = TRUE
		rv = FALSE
	else
        m.diagnostics.PrintDebug("Feed Parse Succeeded")
		m.SetFeed( feed )
		m.loadFailed = FALSE
		rv = TRUE 
	End If

	return rv
End Function


Function pFeedPlayer_HandleVideoEvent( evt As Object ) As Void

    m.diagnostics.PrintDebug("*******************Video Event *************")
	
	if evt.GetInt() = 3 then
		REM Video Event 3 means the video has started, so we need to clear the image plane
        m.diagnostics.PrintDebug("******************  Val = 3  ****************")
        
        REM - Jeff's code below. Updated code clears display as soon as a video is launched
		REM Only if the last item was an image do we need to clear the image plane
'		if not m.lastItemPlayedWasVideo then
'			sleep(500)
'			m.imagePlayer.StopDisplay()
'		endif

		REM Preload the next item if it is an image so that the transition to the image is as fast as possible, we do this here so that
		REM there is not a delay to clear the screen

		item = m.feed.GetNextItem()
		if isImage(item) then
			m.diagnostics.PrintDebug("Preloading next item as it is an image")
			m.preloadItem ( item)
		endif
		m.feed.GoToPrevItem()
	else if evt.GetInt() = 8 then
		REM Video Event 8 means the video has ended, so display the next item
        m.diagnostics.PrintDebug("******************  Val = 8  ****************")
        
		if type(m.stateMachine.activeState) = "roAssociativeArray" then
			m.stateMachine.bsp.logging.WriteEventLogEntry(m.stateMachine, m.stateMachine.activeState.id$, "mediaEnd", "", "1")
		endif

        if m.reachedEnd then
			m.PostSignChannelEndEvent()
		endif

		m.CurrentItem.DurationExpired = True
		
		REM - Jeff's code below cleared video display as soon as the video ended. New code erases video only when an image is displayed.
'		m.videoplayer.StopClear()
		m.lastItemPlayedWasVideo = TRUE
		m.DisplayNextItem()
	end if

End Function


Function pFeedPlayer_HandleTimerEvent( event As Object ) As Void

	eventId = event.GetSourceIdentity()

	if eventId = m.imageTimer.GetIdentity() then
        m.diagnostics.PrintDebug("********************** Image Timer Event *********************")
    	
		if type(m.stateMachine.activeState) = "roAssociativeArray" then
			m.stateMachine.bsp.logging.WriteEventLogEntry(m.stateMachine, m.stateMachine.activeState.id$, "timer", "", "1")
		endif

    	if m.reachedEnd then
	        m.PostSignChannelEndEvent()
	    endif
	
		REM In case the first image of a new feed fails to display, the CurrentItem would 
		m.CurrentItem.DurationExpired = TRUE
		m.lastItemPlayedWasVideo = FALSE
		m.DisplayNextItem()
	else if eventId = m.imageRetryTimer.GetIdentity() then
        m.diagnostics.PrintDebug("********************** Image Retry Timer Event ****************")
		m.DisplayNextItem()
	else if eventId = m.feedTimer.GetIdentity() then
        m.diagnostics.PrintDebug("********************** Feed Timer Event ********************")
		if not m.fetchfeed() then
            m.diagnostics.PrintDebug("Failure on return from fetch feed, reseting retry timer to 30 sec")
			m.addSecsToTimer( 30, m.feedTimer)
		else
			m.diagnostics.PrintDebug("Successful return from fetch feed, resetting timer to:" + stri(m.feed.ttlSeconds) + " seconds")
			m.addSecsToTimer( m.feed.ttlSeconds, m.feedTimer)
		End if
	else
        m.diagnostics.PrintDebug("Got Timer event with no Timer associated with it" + stri(eventId))
	end if
 
End Function


Function pFeedPlayer_GetURL() As String
    if m.rssURL$ = "" then
        return "http://" + m.feedHost + m.GetFeedUri()
    else
        return m.rssURL$
    endif
End Function


Function pFeedPlayer_FetchFeed() As Boolean
	REM print "In Fetch Feed.....*****************************************"
	REM print "***********************************************************"
    m.diagnostics.PrintDebug("FETCH Feed" + m.systemTime.GetUtcDateTime().GetString())
	m.lastLoadAttempt = m.GetTime()
	REM print "pFeedPlayer_FetchFeed lastLoadAttempt=";m.lastLoadAttempt
	REM Create new feed transfer object to work around network that is not connected
	REM at startup
	m.feedTransfer = invalid
	m.feedTransfer = CreateObject("roUrlTransfer")
	m.feedTransfer.SetMinimumTransferRate( 200, 10 )
	m.feedTransfer.SetPort( m.mport )
	m.feedTransfer.SetUrl(m.GetUrl())

	binding% = GetBinding(m.stateMachine.bsp.mediaFeedsXfersEnabledWired, m.stateMachine.bsp.mediaFeedsXfersEnabledWireless)
    m.diagnostics.PrintDebug("### Binding for pFeedPlayer_FetchFeed is " + stri(binding%))
	ok = m.feedTransfer.BindToInterface(binding%)
	if not ok then stop

    m.diagnostics.PrintDebug("Fetching Url=" + m.feedTransfer.GetUrl() + " FeedCache=" + m.feedCache)
	rv =  m.feedTransfer.AsyncGetToFile(m.feedCache)
	REM print "AsyncGetToFile returns ";rv
	if rv = FALSE then
        m.diagnostics.PrintDebug("AsyncGetToFile fails with " + m.feedTransfer.GetFailureReason())
		m.loadFailed = TRUE
		m.loadFailureReason = m.LOAD_TRANSFER_FAILURE
		m.loadInProgress = FALSE
		REM Wait 30 seconds and try to load the feed again
		m.addSecsToTimer (30, m.feedTimer)
	else
		m.loadFailed = FALSE
		m.loadInProgress = TRUE	
   end if
   
   return rv
End Function


Function pFeedPlayer_FeedSwap() As Void
	If m.newFeed = Invalid Then
        m.diagnostics.PrintDebug("Trying to swap feeds, but new feed is Invalid!")
	else
        m.diagnostics.PrintDebug("pFeedPlayer_FeedSwap: performing feed swap")
		m.feed = m.newFeed
		m.feed.SetStartDisplayTime( m.GetTime() )
        m.diagnostics.PrintDebug("************** Swapping Feed - Resetting Timer ****************")
		m.addSecsToTimer (m.feed.ttlSeconds, m.feedTimer)
		REM Delete all unused cached files
		m.diagnostics.PrintDebug("Free space on SD card:" + stri(m.cacheManager.storageInfo.GetFreeInMegabytes()) + " MB")
'		m.cacheManager.Prune(m.feed,m, false)
' switch to ruthless caching until media rss feeds share pool with BSN
' removed because it caused havoc with video files
		m.cacheManager.Prune(m.feed,m, false)
		REM Start the loading of the items in the new feed
		m.LoadNextItem()
		m.newFeed = invalid
	end If
End Function


Function pFeedPlayer_FetchFeedNoAsync() As Boolean
    REM Get a feed synchronously...

	url = m.GetURL()
    m.diagnostics.PrintDebug("Setting url to " + url)
	m.lastLoadAttempt = m.GetTime()
	REM print "pFeedPlayer_FetchFeed lastLoadAttempt=";m.lastLoadAttempt
	REM Create new feed transfer object to work around network that is not connected
	REM at startup
	m.feedTransfer = invalid
	m.feedTransfer = CreateObject("roUrlTransfer")
	m.feedTransfer.SetMinimumTransferRate( 200, 10 )
	m.feedTransfer.SetPort( m.mport )
	m.feedTransfer.SetUrl(url)
	m.feedTransfer.SetMinimumTransferRate(200, 10 )

	binding% = GetBinding(m.stateMachine.bsp.mediaFeedsXfersEnabledWired, m.stateMachine.bsp.mediaFeedsXfersEnabledWireless)
    m.diagnostics.PrintDebug("### Binding for pFeedPlayer_FetchFeedNoAsync is " + stri(binding%))
	ok = m.feedTransfer.BindToInterface(binding%)
	if not ok then stop

	rv =  m.feedTransfer.GetToFile( m.feedCache )
	if rv <> 200 then
        m.diagnostics.PrintDebug("FetchFeedNoAsync roUrlTransfer.GetToFile failed:" + stri(rv))
		m.loadFailed = TRUE
		m.loadFailureReason = m.LOAD_TRANSFER_FAILURE
		rv = false
	else
        m.diagnostics.PrintDebug("roUrlTransfer.GetToFile succeeded:" + stri(rv))
		rv = m.LoadFeedFile()
	end if

   return rv
End Function


Function pFeedPlayer_AddSecsToTimer(seconds as Integer, timer as object) As void
	newTimeout = m.systemTime.GetLocalDateTime()
	newTimeout.AddSeconds(seconds)
	timer.SetDateTime(newTimeout)
	timer.Start()
End Function  


REM ==========================================
REM   pFeedPlayer_DisplayNextItem
REM ==========================================
REM
REM Member in FeedPlayer object
REM
REM Advance to and display next item in feed
REM once current item has finished its duration period
REM
REM ------------------------------------------

Function pFeedPlayer_DisplayNextItem() As Boolean
	rv = false

	REM print "into Display next item*******"

	If m.feed = Invalid then
		REM print "player has no feed loaded"
	else If type(m.feed) <> "roAssociativeArray" then
        m.diagnostics.PrintDebug("Feed is not associative array")
	else If m.currentItem <> Invalid and not m.CurrentItem.DurationExpired Then
		REM print "item not expired yet...returning from display next item"
        m.diagnostics.PrintDebug("****************************************************************************")
        m.diagnostics.PrintDebug("***************************  SHould NEVER GET HERE ************************")
	else
		item = m.feed.GetNextItem()
		if item = invalid
            m.diagnostics.PrintDebug("Item invalid after GetNextItem in DisplayNextItem, feed corruption")
			return rv
		endif

        m.diagnostics.PrintDebug("DISPLAY NEXT - Item Index =" + stri(m.feed.currentItemIdx))

		if isImage(item) then	
			If m.DisplayItem(item ) then
				m.currentItem = item
				m.feed.numTriesToDisplay = 0
				m.CurrentItem.DurationExpired = FALSE
				duration = m.CurrentItem.duration
				m.AddSecsToTimer(duration, m.imageTimer)
				REM post a message to indicate the end of the cycle
				if m.feed.atEnd then 
                    m.reachedEnd = TRUE
					m.mport.PostMessage (m.endCycleEvent)
				end if
				rv = True
			else
				REM keep track of the number of times we have tried to display this item
				m.feed.numTriesToDisplay = m.feed.numTriesToDisplay + 1 

				REM if we have tried less than 5 times to display this image, go back to prev item as to try this one again
				if m.feed.numTriesToDisplay < 5 then
					m.feed.GoToPrevItem()
                    m.diagnostics.PrintDebug("DISPLAY NEXT - retry =" + stri(m.feed.numTriesToDisplay) + "   Item Index =" + stri(m.feed.currentItemIdx))
					REM Retry in 2 seconds
					m.AddSecsToTimer(2, m.imageRetryTimer)
				else
                    m.diagnostics.PrintDebug("******************** TRIED 5 TIMES AND Still Not there  ********")
					m.currentItem = item
					m.feed.numTriesToDisplay = 0
					if m.feed.atEnd then 
				        m.PostSignChannelEndEvent()
						m.mport.PostMessage (m.endCycleEvent)
					end if
					REM Item did not load, go to the next item
					m.AddSecsToTimer(1, m.imageTimer)
				end if
			End If

			REM Preload the next item if it is an image so that the transition to the image is as fast as possible
			item = m.feed.GetNextItem()
			if isImage(item) then
				sleep (1000)
				m.preloadItem ( item)
			endif
			m.feed.GoToPrevItem()
		else
            m.diagnostics.PrintDebug("*****************    PLAY VIDEO  ********************")
			If m.DisplayItem(item ) then
				m.currentItem = item
                m.diagnostics.PrintDebug("******   Video playing")
				m.CurrentItem.DurationExpired = false
				REM post a message to indicate the end of the cycle
				if m.feed.atEnd then
                    m.reachedEnd = TRUE
					m.mport.PostMessage (m.endCycleEvent)
				end if
				rv = TRUE
			else
				REM Item did not load, go to the next item
				if m.feed.atEnd then 
				    m.PostSignChannelEndEvent()
					m.mport.PostMessage (m.endCycleEvent)
				end if
				m.currentItem = item
				m.AddSecsToTimer(1, m.imageTimer)
			End if
		End if
	end if

	return rv
End Function


Function pfeedPlayer_preloadItem (item As Object ) As void
	fname = m.cacheManager.Get(item )
  
	If fname <> invalid then
	
        if not m.IsEnabled then
            return
        endif
	
		if isImage(item) then
			if not item.preloaded then 	
                if type(m.imagePlayer) = "roImageWidget" then
				    If not m.imagePlayer.PreloadFile( fname ) then
                        m.diagnostics.PrintDebug("FROM_CACHE: Preload from cache failed" + fname)
					    item.preloaded = false
				    Else
                        m.diagnostics.PrintDebug("FROM_CACHE: Preload from file succeeded: " + fname)
					    item.preloaded = true
				    End If
		        else
                    m.diagnostics.PrintDebug("Image preload failed - the current layout does not contain an image zone")
		        endif
			end if
		End if
	End if
End Function


Function isImage( item As Object ) As Boolean
	REM Default is the item is an image
	rv = TRUE

	if item.type = "video/mpeg" OR item.type = "video/mp4" OR item.medium = "video" then
		rv = false
	endif

   return rv
End Function


REM ====================================================
REM  pFeedPlayer_DisplayItem
REM
REM  method in FeedPlayer object
REM
REM  Display feed item on screen for <duration> seconds
REM    - fetches content for item
REM    - if content not fetched skips, and lets
REM      FeedPlayer.DisplayNextItem select next 
REM      item to display
REM ====================================================

Function pFeedPlayer_DisplayItem( item As Object ) As Boolean
  
	rv = false 
	If item = Invalid Then
        m.diagnostics.PrintDebug("Invalid item passed to DisplayItem")
	else
		fname = m.cacheManager.Get(item )
		If fname <> invalid then
		
            if not m.IsEnabled then
                return true
            endif
		
			if isImage(item) then
			
				if type(m.imagePlayer) = "roImageWidget" then

					if not item.preloaded then 	
						If not m.imagePlayer.PreloadFile( fname ) then
                            m.diagnostics.PrintDebug("FROM_CACHE: Preload from cache failed " + fname)
							rv = false
						Else
                            m.diagnostics.PrintDebug("FROM_CACHE: Preload from file succeeded: " + fname)
							item.preloaded = true
						End If
					end if

					If item.preloaded and m.imagePlayer.DisplayPreload() then

						m.stateMachine.ShowImageWidget()
    				
                        if type(m.videoPlayer) = "roVideoPlayer" then
                            m.videoPlayer.StopClear()
                        endif
    				
                        m.diagnostics.PrintDebug("FROM_CACHE: Display from cache succeeded " + fname)
						item.preloaded = false
						item.SetDisplayStart( m.GetTime() )
						rv = True

						if type(item.title) = "roString" then
							title$ = item.title
						else
							title$ = "unknown"
						endif

						m.stateMachine.LogPlayStart("image", title$)

					Else
                        m.diagnostics.PrintDebug("FROM_CACHE: Display from file failed or not preloaded: " + fname)
					End If

					REM Set transition after image display to be a fade
					m.imagePlayer.SetDefaultTransition(m.slideTransition%)
					
				else
				
                    m.diagnostics.PrintDebug("Image display failed - the current layout does not contain an image zone")
				
				endif
									
			else
				REM Set transition to put image up immediately after video is finished
				if type(m.imagePlayer) = "roImageWidget" then
					m.imagePlayer.SetDefaultTransition(0)
				endif
                m.diagnostics.PrintDebug("starting video play")
                if type(m.videoPlayer) = "roVideoPlayer" then
					m.videoPlayer.EnableSafeRegionTrimming(false)

					aa = { }
					aa.AddReplace("Filename", fname)
		
					if type(item.probeData) = "roString" and item.probeData <> "" then
						m.diagnostics.PrintDebug("pFeedPlayer_DisplayItem: probeData = " + item.probeData)
						aa.AddReplace("ProbeString", item.probeData)
					endif

					if m.videoPlayer.PlayFile(aa)
						rv = true
						m.stateMachine.ClearImagePlane()
						m.stateMachine.LogPlayStart("video", item.title)
					else
                        m.diagnostics.PrintDebug("**************  Video Player -> PlayFile FAILED!!!! " + fname)
					end if
				else
                    m.diagnostics.PrintDebug("Video playback failed - the current layout does not contain a video zone")
				endif
			end if			
		else
            m.diagnostics.PrintDebug("FROM_CACHE: Item has no cache entry: " + item.guid)
		end if
	end if

	return rv
End Function


Function pFeedPlayer_LoadNextItem() As void	

	REM Get the next item to load
	item = m.feed.GetNextLoadItem(m)

	if item <> invalid then

		REM print "********************** Into LoadNextItem ****************"
		m.diagnostics.PrintDebug("Loading NEXT - Item Index =" + stri(m.feed.currentLoadItemIdx))
		fname = m.cacheManager.Get(item)
  
		REM If the file name is invalid it means the file is not in the cache
		If fname = invalid then
			REM Set up async download of item, indicate the download has started 
			m.diagnostics.PrintDebug("setting up async transfer")
			m.diagnostics.PrintDebug("File name is not valid, so item is NOT in the cache, item=" + stri(m.feed.currentLoadItemIdx))
			if isImage(item) then 
				REM Check to make sure we have not already started another image download
				if m.feed.asyncImageDownloadInProgress = false then
					m.diagnostics.PrintDebug("item indicates download has NOT started - " + item.url)
					m.diagnostics.PrintDebug("Loading NEXT Image - Item Index =" + stri(m.feed.currentLoadItemIdx))
					fname = m.cacheManager.GetFullFileName(item)
					m.feed.imageDownloader = invalid
					m.feed.imageDownloader = CreateObject("roUrlTransfer")
					m.feed.imageDownloader.SetPort( m.mport )
					m.feed.imageDownloader.SetUrl( item.url )
					m.feed.imageDownloader.SetMinimumTransferRate(200,10)
					m.feed.imageDownloader.SetUserData(fname)

					binding% = GetBinding(m.stateMachine.bsp.mediaFeedsXfersEnabledWired, m.stateMachine.bsp.mediaFeedsXfersEnabledWireless)
				    m.diagnostics.PrintDebug("### Binding for pFeedPlayer_LoadNextItem is " + stri(binding%))
					ok = m.feed.imageDownloader.BindToInterface(binding%)
					if not ok then stop

					rv = m.feed.imageDownloader.AsyncGetToFile( fname)
					if rv = FALSE then
                    m.diagnostics.PrintDebug("AsyncGetToFile for image item download fails with " + m.feed.imageDownloader.GetFailureReason())
						REM Kick the load process to start loading the next item
						m.mport.PostMessage (m.loadEvent)
					else
						m.feed.asyncImageDownloadInProgress = true
						m.currentImageLoadItem = item
					end if
				else
					REM Image downloading in progress, post message to download next item in case it is a video
					m.diagnostics.PrintDebug("Image download in progress, post a message to load next item")
					m.mport.PostMessage (m.loadEvent)
				End if
			else
				REM Check to make sure we have not already started another video download
				if m.videoDownloader.asyncVideoDownloadInProgress = false then
					REM print "Item indicates download has not started for video - ";item.url
					if (m.cacheManager.IsSpaceAvailable(item)) then
						m.diagnostics.PrintDebug("Loading NEXT Video - Item Index =" + stri(m.feed.currentLoadItemIdx))
						fname = m.cacheManager.GetFullFileName(item)
						rv = m.videoDownloader.StartDownload(item.url, fname, m.feed.id)
						if rv then
							m.videoDownloader.currentVideoLoadItem = item
						endif
					else
						m.diagnostics.PrintDebug("Space not available for download of item Index =" + stri(m.feed.currentLoadItemIdx))
						REM If we don't have space available for the download, then mark it as downloaded so we don't try again
						item.downloaded = true
					end if
					REM Kick the load process since loading video may take a long time
					m.mport.PostMessage (m.loadEvent)
				else
					REM Video downloading in progress, post message to download next item in case it is an image
					if (m.feed.items.Count() > 1) then
						m.diagnostics.PrintDebug("Video download in progress, post a message to load next item")
						m.mport.PostMessage (m.loadEvent)
					end if
				end if
			end if			
		else
			REM The current item is already cached on the sd card so 
			REM go to the next item by bumping the loader unless we are at then end of the feed
			m.diagnostics.PrintDebug("File name is valid, Item is in the cache, no need to load from the network, item =" + stri(m.feed.currentLoadItemIdx))
			m.feed.items[m.feed.currentLoadItemIdx].downloaded = true
			REM if (not m.feed.atLoadEnd) and (not m.videoDownloader.asyncVideoDownloadInProgress) then 
			if (not m.feed.atLoadEnd) then 
				m.diagnostics.PrintDebug("***********  Item in cache #:" + stri(m.feed.currentLoadItemIdx) + " not at load end, trigger timer ******")
				m.mport.PostMessage (m.loadEvent)
			else
				m.diagnostics.PrintDebug("*********  Item in cache #:" + stri(m.feed.currentLoadItemIdx) + " AT load end, don't trigger timer *********")
			end if
		end if
	else
		m.diagnostics.PrintDebug("Item was invalid from Getnextloaditem")
	end if
End Function


REM ====================================================
REM            pFeedPlayer_SetFeed
REM ====================================================
REM
REM Set accessor w very basic sanity check
REM

Function pFeedPlayer_SetFeed( feed As Object ) As Void

	m.newFeed = feed
	If m.feed = invalid then
		m.feed = m.newFeed
		m.feed.SetStartDisplayTime(m.GetTime())
		m.newFeed = invalid
	end if

End Function


REM =======================================================
REM              ParseFeed
REM =======================================================
REM
REM Input: RSS XML document as String
REM Return:
REM    feedObject if XML parses to a feed with one or more valid feed items
REM    invalid if XML not parseable or feed contains no valid feed items
REM

Function pFeedPlayer_ParseFeed( xml As String ) As Object

    feed = invalid
	feedDoc=CreateObject("roXMLElement")
	if not feedDoc.Parse(xml)
        m.diagnostics.PrintDebug("Parse failed")
		feed = invalid
		m.loadFailureReason = m.LOAD_INVALID_XML
	else
		feed = newFeed( feedDoc, m )
		m.PopulateFeedItems( feed, feedDoc )

		if feed.items = invalid  then
			feed = invalid
			m.loadFailureReason = m.LOAD_EMPTY_RSS
		else if feed.items.Count() = 0 then
			feed = invalid
			m.loadFailureReason = m.LOAD_EMPTY_RSS
		else 
			feed.ListItems()
		end if
	end if

	return feed

End Function


REM
REM =======================================================
REM                     Feed Object
REM =======================================================
REM

Function newFeed( xmlDoc As Object, feedPlayer As Object ) As Object
	feed = { ttlSeconds:900, currentItemIdx:-1, overscanFactor:1.0, numTriesToDisplay:0, unregistered:false,currentLoadItemIdx:-1, atEnd:False, atLoadEnd:False}
	feed.items = CreateObject("roArray", 0, TRUE )
	feed.playtime = invalid
	feed.loadTime = feedPlayer.GetTime() 
	feed.GetTTLSeconds = pFeed_GetTTLSeconds
	feed.GetNextItem = pFeed_GetNextItem
	feed.GetNextLoadItem = pFeed_GetNextLoadItem
	feed.GoToPrevItem = pFeed_GoToPrevItem
	feed.SetTTLMinutes = pFeed_SetTTLMinutes
	feed.ListItems = pFeed_ListItems
	feed.GetPlaytimeSeconds = pFeed_GetPlaytimeSeconds
	feed.SetStartDisplayTime = pFeed_SetStartDisplayTime
	feed.CycleComplete = pFeed_CycleComplete
	feed.imageDownloader = CreateObject("roUrlTransfer")
	feed.imageDownloader.SetPort(feedPlayer.mport)
	feed.asyncImageDownloadInProgress = false
	feed.startDisplayTime = invalid
    feed.feedPlayer = feedPlayer
    feed.diagnostics = feedPlayer.diagnostics

    systemTime = CreateObject("roSystemTime")
	currentDateTime = systemTime.GetLocalDateTime()
	feed.id = currentDateTime.GetString()

	return feed
End Function


Function pFeed_SetStartDisplayTime(t As Integer) As Void
	m.startDisplayTime = t
End Function


Function pFeed_GetPlaytimeSeconds( ) As Integer
	If m.playtime = invalid Then
		return m.GetTTLSeconds()
	else
		return m.playtime
	end if
End Function


Function pFeed_GetTTLSeconds() As Integer
	return m.ttlSeconds
End Function


Sub pFeedPlayer_PopulateFeedItems( feed as Object, feedDoc as Object )

	REM Ideally should be getList returning a list
	REM to be used in caller as feed.items = getFeedItems(...)
	REM Experimenting around that now to find cause of 
	REM interpreter/OS crash

	for each elt in feedDoc.GetBody().Peek().GetBody()
		name = elt.GetName()

		if name = "ttl" then
			feed.SetTTLMinutes( elt.GetBody() )
		else if name = "frameuserinfo:playtime" Then
			feed.playtime = Val(elt.GetBody())
		else if name = "frameuserinfo:unregistered" then
			unregstate = elt.GetBody()
			if unregstate = "TRUE" then
				feed.unregistered = true
			else
				feed.unregistered = false
			endif
		else if name = "title" then
			feed.title = elt.GetBody()
		else if elt.GetName() = "item" then
			item = newFeedItem(elt)
			if (item <> invalid) then 
				feed.items.Push( item )
			end if	
		end if
	next

End Sub


Function pFeed_SetTTLMinutes( ttl As String ) As Void
	if ttl = invalid or Val(ttl) <= 0 then
		m.ttlSeconds = 900
	else if Val(ttl) < 2 then
		m.ttlSeconds = 120
	else
		m.ttlSeconds = Val(ttl) * 60
	end if

	' the ttl is the lower of the ttl specified in the feed and the update rate of the live data (if a live data is in use)
	if m.feedPlayer.liveDataFeedUpdateInterval% > 0 and m.feedPlayer.liveDataFeedUpdateInterval% < m.ttlSeconds then
		m.ttlSeconds = m.feedPlayer.liveDataFeedUpdateInterval%
	endif

End Function


Function pFeed_GetNextItem() As Object
	item = invalid
	m.atEnd = False

	If m.items = invalid Then
        m.diagnostics.PrintDebug("No item list")
		m.atEnd = True
	else if m.items.IsEmpty() Then
        m.diagnostics.PrintDebug("Item list empty")
		m.atEnd = True
	else
		m.currentItemIdx = m.currentItemIdx + 1

		If m.currentItemIdx >= m.items.Count() then
			if m.items.count() = 1 then
				m.atEnd = true
			end if
			m.currentItemIdx = 0
		else if m.currentItemIdx = m.items.Count() - 1 then
			m.atEnd = True
		End If

		item =  m.items.GetEntry( m.currentItemIdx )
	end if

	return item
End Function


Function pFeed_GetNextLoadItem(feedplayer as Object) As Object
	endOfList = false

	If m.items = invalid Then
        m.diagnostics.PrintDebug("No item list")
		endOfList = True
		return invalid
	End If

	If m.items.IsEmpty() Then
        m.diagnostics.PrintDebug("Item list empty")
		endOfList = True
		return invalid
	End If

	m.currentLoadItemIdx = m.currentLoadItemIdx + 1
	If m.currentLoadItemIdx >= m.items.Count() then
		endOfList = true
		m.diagnostics.PrintDebug("Setting m.currentLoadItemIdx to ZERO")
		m.currentLoadItemIdx = 0
	End If

	foundNextItem = false
	while ( not foundNextItem and not endOfList)
		if m.items[m.currentLoadItemIdx].downloaded then
			m.diagnostics.PrintDebug("item downloaded, adding 1 to the index m.currentLoadItemIdx =" + stri(m.currentLoadItemIdx))
			m.currentLoadItemIdx = m.currentLoadItemIdx + 1
			If m.currentLoadItemIdx >= m.items.Count() then
				endOfList = true
				m.diagnostics.PrintDebug("Setting m.currentLoadItemIdx to ZERO at end of list with item downloaded")
				m.currentLoadItemIdx = 0
			end if
		else
			if isImage(m.items[m.currentLoadItemIdx]) then
				m.diagnostics.PrintDebug("item NOT downloaded, IMAGE, found it true, m.currentLoadItemIdx =" + stri(m.currentLoadItemIdx))
				foundNextItem = true
			else if feedplayer.videoDownloader.asyncVideoDownloadInProgress then
				m.diagnostics.PrintDebug("asyncVideoDownloadInProgress, adding 1 to the index m.currentLoadItemIdx =" + stri(m.currentLoadItemIdx))
				m.currentLoadItemIdx = m.currentLoadItemIdx + 1
				If m.currentLoadItemIdx >= m.items.Count() then
					endOfList = true
					m.diagnostics.PrintDebug("Setting m.currentLoadItemIdx to ZERO because we hit the End of list while DOWNLOADING Video")
					m.currentLoadItemIdx = 0
				end if
			else if (feedplayer.cacheManager.IsSpaceAvailable(m.items[m.currentLoadItemIdx])) then
				foundNextItem = true
				m.diagnostics.PrintDebug("Found the item, m.currentLoadItemIdx=" + stri(m.currentLoadItemIdx))
			else
				m.diagnostics.PrintDebug("Video Item not able to be downloaded =" + stri(m.currentLoadItemIdx))
				m.items[m.currentLoadItemIdx].downloaded = true				' indicate the item is downloaded so we will skip it in the future
				m.currentLoadItemIdx = m.currentLoadItemIdx + 1
				If m.currentLoadItemIdx >= m.items.Count() then
					endOfList = true
					m.diagnostics.PrintDebug("Setting m.currentLoadItemIdx to ZERO because we hit the End of list while unable to download Video")
					m.currentLoadItemIdx = 0
				end if
			end if		
		End If		
	end while

	if m.items[m.currentLoadItemIdx].downloaded then
		m.diagnostics.PrintDebug("Item index:" + stri(m.currentLoadItemIdx) + " has been downloaded")
	else
		m.diagnostics.PrintDebug("Item index:" + stri(m.currentLoadItemIdx) + " has NOT been downloaded")
	end if

	REM If we have reached then end of the list for downloading, make sure all items downloaded successfully
	if endOfList then
		i = 0
		itemNotDownloaded = -1
		allItemsDownloaded = true
		waitingForVideo = false
		while (i < m.items.Count()) and itemNotDownloaded = -1 
			if not m.items[i].downloaded then
				REM if not isImage(m.items[i]) then
					REM if (not feedplayer.videoDownloader.asyncVideoDownloadInProgress) then
						itemNotDownloaded = i
					REM end if
				REM end if
				allItemsDownloaded = false
			endif
			i = i + 1
		end while

		if itemNotDownloaded <> -1 then
			m.diagnostics.PrintDebug("End of list but found item:" + stri(itemNotDownloaded) + " was NOT downloaded yet")
			m.currentLoadItemIdx = itemNotDownloaded
		else if allItemsDownloaded then
			m.diagnostics.PrintDebug("End of list reached AND all items have been downloaded")
			m.atLoadEnd = true
		end if

		if m.atLoadEnd  then
			m.diagnostics.PrintDebug("At load end, setting return to Invalid")
			rv = Invalid		
		else if (not IsImage (m.items.GetEntry( m.currentLoadItemIdx )) and  feedplayer.videoDownloader.asyncVideoDownloadInProgress)
			m.diagnostics.PrintDebug("Item is NOT an IMAGE and ASYNC video download in progress")
			rv = Invalid
		else if IsImage(m.items.GetEntry( m.currentLoadItemIdx )) and m.asyncImageDownloadInProgress then
			m.diagnostics.PrintDebug("Item IS an IMAGE and ASYNC image download in progress")
			rv = Invalid
		else
			rv =  m.items.GetEntry( m.currentLoadItemIdx )
		end if
	else
		rv =  m.items.GetEntry( m.currentLoadItemIdx )
	end if
	
	return rv

End Function


Function pFeed_GoToPrevItem() As void

   REM make sure the item list is valid and that the list is not empty
   If m.items = invalid Then
      m.diagnostics.PrintDebug("No item list")
      m.atEnd = True
      return 
   else if m.items.IsEmpty() Then
      m.diagnostics.PrintDebug("Item list empty")
      m.atEnd = True
      return
   End If

   REM set the current index to the previous item
   m.currentItemIdx = m.currentItemIdx - 1

   REM if decreasing the current index made it negative (cause we were at 0), go to the end of the list
   If m.currentItemIdx < 0 then
      m.currentItemIdx = m.items.Count() - 1
   End If
   
   REM set the at End flags to represent the current condition after decreasing the index
   If m.currentItemIdx = m.items.Count() - 1 then
      m.atEnd = True
   Else
      m.atEnd = False
   End If

   return

End Function


Function pFeed_CycleComplete() As Boolean
    If m.items = invalid Then
        m.diagnostics.PrintDebug("pFeed_CycleComplete() Item list is null, returning True")
        return True
    End If
    If m.items.IsEmpty() Then
        m.diagnostics.PrintDebug("pFeed_CycleComplete() Item list is empty, returning True")
        return True
    End If

    If m.atEnd Then
        return True
    End If

    return False

End Function


Function pFeed_ListItems() As Void
  For each item in m.items
  Next
End Function


REM
REM =================================================
REM        FeedItem Object
REM =================================================
REM
REM

Function newFeedItem( xml as Object ) As Object
	item = { guid:"placeholder", durationSeconds: 60, url:"no_url", category:"no_category", thumbnail:"no_thumbnail", title:"no_title", displayStart:0, medium:"no_medium", size:0}

	contentPresent = false

	for each elt in xml.GetBody()
		name = elt.GetName()
		if name = "guid" then
			item.guid = elt.GetBody()
		else if name = "title" then
			item.title = elt.GetBody()
		else if name = "description" then
			item.description = elt.GetBody()
		else if name = "media:content" then
			item.url= elt.GetAttributes()["url"]
			item.type = elt.GetAttributes()["type"]
			item.duration = helper_GetDuration( elt )
			item.size = helper_GetFileSize(elt)
			item.medium = elt.GetAttributes()["medium"]
			contentPresent = true
			item.probeData = helper_GetProbeData(elt)
		else if name = "media:thumbnail" then
			item.thumbnail = elt.GetAttributes()["url"]
		else if name = "category" then
			item.category = elt.GetBody()
		end if
	next

	item.DurationExpired = TRUE
	item.SetDisplayStart = pFeedItem_SetDisplayStart
	item.GetDisplayStart = pFeedItem_GetDisplayStart
	item.Print = pFeedItem_Print
	item.GetExtension = pFeedItem_GetExtension
	item.preloaded = false
	item.downloaded = false

   ' fixup item.guid as needed
    if IsString(item.guid) then
        item.guid = CleanGuid(item.guid)
    else
        item.guid = StripLeadingSpaces(str(rnd(100000)))
    endif

	if (contentPresent) then 
		return item
	else 
		return invalid
	end if

End Function


Function CleanGuid(guidIn As String) As String
    charsToReplace = [ "/", ":", ",", ".", "&", "=", "?"]
    guid = guidIn
    for each charToReplace in charsToReplace
        index = 1
        while index <> 0
            index = instr(1, guid, charToReplace)
            if index <> 0 then
                part1 = ""
                if (index - 1) > 0 then
                    part1 = mid(guid, 0, index - 1)
                endif
                part2 = ""
                if (len(guid) - index) > 0 then
                    part2 = mid(guid, index + 1, len(guid) - index)
                endif
                guid = part1 + "-" + part2
            endif
        end while
    next
    return guid
End Function


Function pFeedItem_GetExtension() as String
   REM print "in getextension"
   if m.type = "image/jpeg" then
      REM print "type image/jpg"
      return ".jpg"
   else if m.type = "image/png" then
       REM print "type .png"
	   return ".png"
   else if m.type = "image/gif" then
	   REM print "type .gif"
       return ".gif"
   else if m.type = "video/mpeg" or m.type = "video/mp4" then
	   REM print "type  .mp4"
	   return ".mp4"
   endif
   ' print "returning default .jpg"
   return ".jpg"
End Function

Function pFeedItem_Print() As Void
  ' print "duration=";m.duration;" title=";m.title;" category=";m.category;" displayStart=";m.displayStart;" url=";m.url
End Function


Function pFeedItem_GetDisplayStart() As Integer
   return m.displayStart
End Function


Function pFeedItem_SetDisplayStart( t As Integer ) As Void

   If t = Invalid Then
'     print "Invalid value for SetDisplayStart"
     return
   End If

   If t <= 0 then
'     print "Set Display Start time is less than Zero - Invalid"
     return
   End If

   if t < m.displayStart then
'     print "SetDisplayStart received value less then current display start"
     return
   end if

   m.displayStart = t

End Function


REM ================================================================
REM          helper_GetDuration
REM ================================================================
REM
REM Get duration attribute of a media:content sub element 
REM of RSS Item element.  Duration is number of seconds for
REM image to be displayed on screen.
REM
REM If no duration found sets default of 15.
REM If duration < 5 seconds sets minimum of 5
REM

Function helper_GetDuration( contentElement As Object ) As Integer

   duration = contentElement.GetAttributes()["duration"]

   if duration = Invalid then
       return 15
   end if

   duration = Val(duration)

'   if duration < 5 then
'      duration = 5
'   end if

   return duration

End Function


Function helper_GetFileSize( contentElement As Object ) As Integer

   size = contentElement.GetAttributes()["fileSize"]

   if size = Invalid then
       return 0
   end if

   fileSize = Val(size)

   return fileSize

End Function


Function helper_GetProbeData( contentElement As Object ) As String

   probe = contentElement.GetAttributes()["probe"]

   if probe = Invalid then
       return ""
   end if

   return probe

End Function

'endregion

'region CacheManager
'=========================================================
'                Cache Manager
'=========================================================

Function newCacheManager(diagnostics As Object) As Object
	rv = {lowestVideoCacheItemNumber:100000000}
	rv.systemTime = CreateObject("roSystemTime")
	rv.storageInfo = CreateObject("roStorageInfo", "./")

	rv.diagnostics = diagnostics
	
	rv.cachedir = "/cache/"
	CreateDirectory(rv.cachedir)

	rv.Videocachedir = "/videocache/"
	CreateDirectory(rv.Videocachedir)

	rv.cacheIndexdir = "/videoCacheIndex/"
	CreateDirectory(rv.cacheIndexdir)

	rv.cacheIndexFile = "/cacheIndexFile"
	indexString = ReadAsciiFile(rv.cacheIndexFile)
	If indexString = invalid or len(indexString) = 0 then
		rv.cacheIndex = 0
		WriteAsciiFile(rv.cacheIndexFile, STR(rv.cacheIndex))
	else
		indexString = Box(indexString).trim()
		if indexString <> invalid then
			rv.cacheIndex = Val(indexString)
'			print "Starting with Video Cache Index =";rv.cacheIndex
		else
			rv.cacheIndex = 0
			WriteAsciiFile(rv.cacheIndexFile, STR(rv.cacheIndex))
		end if
	end if

	rv.reservedAmountOnCard = 100 * 1024 *1024	'reserve 100 MB on card

	rv.Get = pCacheManager_Get
	rv.GetCacheDir = pCacheManager_GetCacheDir
	rv.Prune = pCacheManager_Prune
	rv.Add = pCacheManager_Add
	rv.GetFullFileName =  pCacheManager_GetFullFileName
	rv.GetBaseFileName =  pCacheManager_GetBaseFileName
	rv.GetFileNameWithoutExtension = pCacheManager_GetFileNameWithoutExtension
	rv.GetCacheIndex = pCacheManager_GetCacheIndex
	rv.newFileListItem = pCacheManager_newFileListItem
	rv.BuildOrderedList = pCacheManager_BuildOrderedList
	rv.IsSpaceAvailable = pCacheManager_IsSpaceAvailable
	rv.CleanImageCache = pCacheManager_CleanImageCache

	return rv
End Function


Function pCacheManager_Add(item as Object) As Object
	fname = m.GetBaseFileName(item)
	if isImage(item) then
		REM Do nothing if it is an image
	else
		cacheIndex = m.GetCacheIndex()
		m.cacheIndex = m.cacheIndex + 1

		REM write the index number as a file with name of the file as it's contents
		WriteAsciiFile(m.cacheIndexdir + STR(m.cacheIndex), fname)

		REM Update the Index file with the last Index
		WriteAsciiFile(m.cacheIndexFile, STR(m.cacheIndex))
	end if
	
End Function

Function pCacheManager_GetBaseFileName( item ) as String
	ext = item.GetExtension()
	baseName = item.guid + ext

    return baseName
End Function


Function pCacheManager_GetCacheDir( fileName$ As String ) As String

	poolChars$ = Right(fileName$, 2)
	folder1Char$ = Left(poolChars$, 1)
	folder2Char$ = Right(poolChars$, 1)

	folder1$ = m.cachedir + folder1Char$ + "/"
	CreateDirectory(folder1$)
	
	folder2$ = folder1$ + folder2Char$ + "/"
	CreateDirectory(folder2$)

	return folder2$

End Function


Function pCacheManager_GetFileNameWithoutExtension( fileName$ ) as String

' strip extension if it exists
	if len(fileName$) > 4 then
		return Left(fileName$, len(fileName$) - 4)
	else
		return fileName$
	endif

End Function


Function pCacheManager_GetFullFileName( item ) as String
	
	baseName = m.GetBaseFileName (item)
	if isImage(item) then
		fullName = m.GetCacheDir( item.guid ) + baseName
	else
		fullName = m.Videocachedir + baseName
	end if

    return fullName
End Function

Function pCacheManager_Get(item as Object) As Object
	
	fname = m.GetBaseFileName(item)
	if isImage(item) then
		cacheDir = m.GetCacheDir( item.guid )
		files = MatchFiles(cacheDir, fname)
		if files.Count() > 0 then
			rv = m.GetCacheDir( item.guid ) + files[0]
			REM print "CACHE_HIT: File " + fname
			return rv
		else
			REM print "CACHE_MISS: No file " + fname 
			return Invalid
		end if
	else
		files = MatchFiles( m.Videocachedir, fname)
		if files.Count() > 0 then
			rv = m.videocachedir + files[0]
			REM print "CACHE_HIT: File " + fname
			return rv
		else
			REM print "CACHE_MISS: No file " + fname 
			return Invalid
		end if
	end if
End Function


Function pCacheManager_Prune(feed as Object, feedPlayer as Object,forceClean as boolean) As Object

	m.diagnostics.PrintDebug("Pruning Files.....")

	REM  If there is less than 100 MB on the card prune the image cache
	sdfreeSpace = m.storageInfo.GetFreeInMegabytes()
	m.diagnostics.PrintDebug("SD Free Space =" + stri(sdfreeSpace))
	
	REM Determine which items are not in the cache and add up their size
	spaceNeeded = 0
	sizeIndicated = false
	if (feed.items.Count() > 0) then 
		for i=0 to feed.items.Count() - 1
			item = feed.items.GetEntry(i)
			if item.size <> 0 then
				sizeIndicated = true
			endif
			itemFileName = m.Get( item )
			if itemFileName = Invalid then 
				spaceNeeded = spaceNeeded + item.size
			end if
		next
	end if
	m.diagnostics.PrintDebug("Space Needed =" + str(spaceNeeded/(1024 * 1024)) + "MB")
	
	REM if the current item is a video and it has not finished playing, we need to make sure we don't delete it
	if (feedPlayer.currentItem <> invalid) then
		if (not (isImage(feedPlayer.currentItem)) and not feedPlayer.currentItem.DurationExpired) then
			currentFilePlaying = m.GetBaseFileName(feedPlayer.currentItem) 
			m.diagnostics.PrintDebug("Current File Playing =" + currentFilePlaying)
		else
			REM a work around to force all video files to be closed, playing a file that will not play!
			if type(feedplayer.videoplayer) = "roVideoPlayer" then
				feedplayer.videoplayer.PlayFile("software revision.txt")
			endif
			currentFilePlaying = invalid
		end if
	else
		currentFilePlaying = invalid
	endif

	REM If the size of each item is not specifed in the feed, use the simple caching for video 
	REM which means if it is not in the current feed, get rid of it
	if (not sizeIndicated) or forceClean then
		REM Only prune the files if less than 100 MB remains free on the card
		if (sdfreeSpace < 100) or forceClean then
			REM Prune all images not in the current feed
			m.CleanImageCache(feed, forceClean)
			m.diagnostics.PrintDebug("Size is NOT indicated, pruning all files not in feed")
			REM Delete all unneeded files in the video cache
			files = MatchFiles(m.videocachedir, "*")
			m.diagnostics.PrintDebug("File count in dir " + m.videocachedir + stri(files.Count()))
			for each file in files
				found = false
				if (feed.items.Count() > 0 ) then 
					for i=0 to feed.items.Count() - 1
						item = feed.items.GetEntry(i)
						itemFileName = m.GetBaseFileName( item )
						if itemFileName = file then 
							found = true
						end if
						REM Leave temp files alone if the video download is in progress
						if (feedPlayer.videoDownloader.asyncVideoDownloadInProgress and "tmp" = right(file,3))
							found = true
						end if
					next
				endif
				if not found or forceClean then
					if (currentFilePlaying <> file) then
						m.diagnostics.PrintDebug("Video File Deleted:" + file)
						DeleteFile( m.videocachedir + file )
					end if
				end if
			next
		end if
	else
		m.diagnostics.PrintDebug("Size is indicated, pruning only files for space needed")
		REM Use the maximum amount of space on the card by only deleting image and video files when we required

		REM Delete all .tmp files unless a video download is in progress
		files = MatchFiles(m.videocachedir, "*")
		for each file in files
			if (not feedPlayer.videoDownloader.asyncVideoDownloadInProgress and "tmp" = right(file,3))
				m.diagnostics.PrintDebug("Deleting video temp file =" + file)
				DeleteFile( m.videocachedir + file )
			end if
		next

		m.storageInfo = CreateObject("roStorageInfo", "./")
		freeSpace = m.storageInfo.GetFreeInMegabytes() - (m.reservedAmountOnCard/(1024*1024))	' Keep reserve amount free
		m.diagnostics.PrintDebug("Before Pruning Free space =" + stri(freeSpace) + "MB with addl reserved space of =" + stri(m.reservedAmountOnCard/(1024*1024)) + "MB")
		spaceNeeded = spaceNeeded / (1024 * 1024)										' Convert to MB
		m.diagnostics.PrintDebug("Space Needed =" + str(spaceNeeded) + "MB")

		REM  Delete the image files to try and free space if it is needed
		if spaceNeeded > freeSpace then
			REM Prune all images not in the current feed
			m.CleanImageCache(feed, forceClean)
		end if

		REM Calculate free space after pruning images
		m.storageInfo = CreateObject("roStorageInfo", "./")
		freeSpace = m.storageInfo.GetFreeInMegabytes() - (m.reservedAmountOnCard/(1024*1024))	' Keep reserve amount free
		m.diagnostics.PrintDebug("After Pruning Images Free space =" + str(freeSpace) + "MB with addl reserved space of =" + str(m.reservedAmountOnCard/(1024*1024)) + "MB")
		
		REM If we still need more space, delete the video files			
		if spaceNeeded > freeSpace then
			m.fileItems = CreateObject("roArray", 0, TRUE )					
			m.lowestVideoCacheItemNumber = 100000000    ' set to a very high number
			files = MatchFiles(m.cacheIndexdir, "*")
			for each file in files	
				newItem = m.newFileListItem(file, m.cacheIndexdir, m.Videocachedir)
				m.fileItems.Push(newItem)
			next

			orderedList = CreateObject("roArray", 0, TRUE )	
			m.BuildOrderedList (m.fileItems, orderedList)
			spaceNeeded =  spaceNeeded - freeSpace
			spaceFreed = 0
			itemNumber = 0
			m.diagnostics.PrintDebug("SpaceFreed =" + stri(spaceFreed) + "MB  SpaceNeeded =" + str(spaceNeeded) + "MB")
			while (itemNumber < orderedList.Count()) and (spaceFreed < spaceNeeded)
				infeed = false
				if (feed.items.Count() > 0) then 
					for i=0 to feed.items.Count() - 1
						if (orderedList[itemNumber].targetFileName = m.GetBaseFileName(feed.items[i])) then
							m.diagnostics.PrintDebug("Item is in feed =" + orderedList[itemNumber].targetFileName)
							infeed = true
						end if
					next
				endif
				if not infeed or orderedList[itemNumber].markedForDeletion then
					if ( currentFilePlaying <> orderedList[itemNumber].targetFileName) then
						m.diagnostics.PrintDebug("Item not in feed deleting file =" + orderedList[itemNumber].targetFileName + " and index file =" + orderedList[itemNumber].FileName)
						if (orderedList[itemNumber].targetFileName <> invalid) then
							DeleteFile(m.Videocachedir + orderedList[itemNumber].targetFileName)
						end if
						if (orderedList[itemNumber].FileName <> invalid) then
							DeleteFile(m.cacheIndexdir + orderedList[itemNumber].FileName)
						end if
						spaceFreed = spaceFreed + (orderedList[itemNumber].size/(1024*1024))
						m.diagnostics.PrintDebug("Space Freed =" + str(spaceFreed) + "  spaceNeeded =" + str(spaceNeeded))
					else
						m.diagnostics.PrintDebug("Current video file should be deleted but is playing, it will not be deleted" + currentFilePlaying)
					end if
				end if
				itemNumber = itemNumber + 1
			end while
			m.storageInfo = CreateObject("roStorageInfo", "./")
			freeSpace = m.storageInfo.GetFreeInMegabytes() - (m.reservedAmountOnCard/(1024*1024))	' Reserve 100 MB on card
			m.diagnostics.PrintDebug("After Pruning Free space =" + str(freeSpace) + "MB with addl reserved space of =" + str(m.reservedAmountOnCard/(1024*1024)) + "MB")
		end if
	end if

End Function

	
Function pCacheManager_GetCacheIndex() As Integer
	return m.cacheIndex
End Function


Function pCacheManager_newFileListItem( fileName as String, indexDirectory as String, targetDirectory as String ) As Object
	item = {seqNumber:invalid, fileName:invalid, targetFileName:invalid, size:invalid, markedForDeletion:false}

	item.fileName = fileName
	m.diagnostics.PrintDebug("fileName =" + fileName)
	item.seqNumber = val(fileName)
	m.diagnostics.PrintDebug("seqNumber = " + stri(item.seqNumber))

	REM Get size of the file
	checkFile = CreateObject("roReadFile", indexDirectory + fileName)
	if checkFile = invalid then
		item.size = 0
		m.diagnostics.PrintDebug("Size set to zero because index file could not be opened")
	else
		item.targetFileName = ReadAsciiFile(indexDirectory + fileName)
		m.diagnostics.PrintDebug("Target file name =" + item.targetFileName)
		if item.targetFileName = invalid or len(item.targetFileName) = 0 then
			item.size = 0
			item.markedForDeletion = true
			m.diagnostics.PrintDebug("Set size to zero and marked for deletion because target file name was invalid")
		else
			checkFile = CreateObject("roReadFile", targetDirectory + item.targetFileName)
			if (checkFile <> invalid) then
				checkFile.SeekToEnd()
				item.size = checkFile.CurrentPosition()
				m.diagnostics.PrintDebug("Size set to " + stri(item.size) + " using current position")
			else
				item.size = 0
				item.markedForDeletion = true
			end if			
		end If
	end if

	return item
end Function


Function pCacheManager_BuildOrderedList(inputList as Object, OrderedList as Object)

	m.diagnostics.PrintDebug("into build ordered list, count of list =" + stri(inputList.Count()))
	while ((inputList.Count()) > 0)
		lowestIndex = 0
		for i=0 to inputList.Count() -1
			m.diagnostics.PrintDebug("lowest seq number =" + stri(inputList[lowestIndex].seqNumber) + "   i =" + stri(i) + " seq number =" + stri(inputList[i].seqNumber))
			if (inputList[i].seqNumber < inputList[lowestIndex].seqNumber) then
				m.diagnostics.PrintDebug("lowest seq number being changed")
				lowestIndex = i
			end if
		next
		OrderedList.Push(inputList[lowestIndex])
		inputList.Delete(lowestIndex)
	end while	
End Function

Function pCacheManager_IsSpaceAvailable(item as Object) as Boolean
	m.storageInfo = CreateObject("roStorageInfo", "./")
	freeSpace = m.storageInfo.GetFreeInMegabytes() - (m.reservedAmountOnCard/(1024*1024))
	m.diagnostics.PrintDebug("Freespace (IsAvailable) = " + stri(freeSpace))
	m.diagnostics.PrintDebug("Item size =" + stri(item.size/(1024*1024)))
	if (item.size/(1024*1024)  < freeSpace) then 
		m.diagnostics.PrintDebug("Yes space is available")
		rv = true
	else
		rv = false
		m.diagnostics.PrintDebug("Space is NOT available")
	end if

	return rv
End Function


Function pCacheManager_CleanImageCache(feed as Object, forceClean as boolean) As Object

	REM Delete all unneeded files in the image cache directory
	files = GetContentFiles(m.cachedir)

	for each fileKey in files
		file = files.Lookup(fileKey)
		found = false
		if (feed.items.Count() > 0) then 
			for i=0 to feed.items.Count() - 1
				item = feed.items.GetEntry(i)
				itemFileName = m.GetBaseFileName( item )
				if itemFileName = file then 
					found = true
				end if
			next
		endif
		if not found or forceClean then
			m.diagnostics.PrintDebug("Image File Deleted:" + file)
			cacheDir = m.GetCacheDir(m.GetFileNameWithoutExtension(file))
			DeleteFile( cacheDir + file )
		end if
	next 
End Function


Function GetHost() As String
	return "rss.signchannel.com"
End Function


Function pFeedPlayer_GetFeedUri() As String
	REM return "/productId=MZ" + m.model + "/frameId=" + m.deviceInfo.GetDeviceUniqueId() + "/version=" + GetRevision() 
   
	REM return "/productId=RK" + "MZ210" + "/frameId=" + m.deviceInfo.GetDeviceUniqueId() + "/version=" + GetRevision()
'	if m.model = "MZ210" then
'		productID = "RKMZ210"
'	else
'		productID = "RK" + m.model
'	end if
'	firmwareString = box(str(m.firmwareID)).trim()
'	return "/productId=" + productID + "/frameId=" + m.deviceInfo.GetDeviceUniqueId() + "/firmware=" + firmwareString
	
'	return "/productId=RK" + m.deviceInfo.GetModel() + "/frameId=" + m.deviceInfo.GetDeviceUniqueId() + "/version=" + GetSignChannelRevision() + "/resx=" + resx + "/resy=" + resy
	return "/productId=RK" + m.model + "/frameId=" + m.deviceInfo.GetDeviceUniqueId() + "/version=" + GetSignChannelRevision()

End Function


Function GetSignChannelRevision() As String
  s = "$Revision: 315 $"
  start = instr(0, s, " ")
  s=Right(s, len(s)-start)
  fin = instr(0,s," ")
  return Left(s, fin-1)
End Function                          

'endregion

'region FeedVideoDownloader
REM ==================================================
REM           FeedVideoDownloader Object
REM ==================================================
REM 
REM 
Function newFeedVideoDownloader(bsp As Object) As Object
	
    fvd = { name:"VideoDownloader" }
    
	fvd.videoDownloader = CreateObject("roUrlTransfer")
	fvd.videoDownloader.SetPort(bsp.msgPort)
	fvd.bsp = bsp
	fvd.msgPort = bsp.msgPort
	fvd.diagnostics = bsp.diagnostics
    
    fvd.HandleURLEvent = HandleVideoDownloaderURLEvent
    fvd.StartDownload = StartDownload
    fvd.asyncVideoDownloadInProgress = false
	fvd.currentVideoLoadItem = Invalid
    
    return fvd
    
End Function


Function StartDownload(url As String, fname As String, feedId As String) As Object

	m.feedId = feedId

	m.videoDownloader = invalid
	m.videoDownloader = CreateObject("roUrlTransfer")
	m.videoDownloader.SetPort(m.msgPort)

	m.videoDownloader.SetUrl( url )
	m.videoDownloader.SetMinimumTransferRate(200,10)
	m.videoDownloader.SetUserData(fname)

	binding% = GetBinding(m.bsp.mediaFeedsXfersEnabledWired, m.bsp.mediaFeedsXfersEnabledWireless)
    m.diagnostics.PrintDebug("### Binding for StartDownload (video) is " + stri(binding%))
	ok = m.videoDownloader.BindToInterface(binding%)
	if not ok then stop

	rv = m.videoDownloader.AsyncGetToFile(fname)
	if rv = FALSE then
		m.diagnostics.PrintDebug("AsyncGetToFile for video item download fails with " + stri(m.videoDownloader.GetFailureReason()))
	else
		m.asyncVideoDownloadInProgress = true
	end if
		
	return rv
				
End Function


Sub HandleVideoDownloaderURLEvent(event As Object, feedPlayer As Object)

	REM print "URL EVENT "; event
	REM print "URL EVENT CODE: ";event.GetResponseCode()
	REM print "URL EVENT STATUS: ";event.GetInt()
	REM print "URL SOURCE";event.GetSourceIdentity()

	eventId = event.GetSourceIdentity()
	eventCode = event.GetResponseCode()
	eventStatus = event.GetInt()

	if eventId = m.videoDownloader.GetIdentity() then
		m.diagnostics.PrintDebug("URL - DOWNLOAD VIDEO")
		if eventStatus = 2 then
			m.diagnostics.PrintDebug("DOWNLOAD in PROGRESS")
		else if eventStatus = 1 then
			if (eventCode <> 200) then
				m.diagnostics.PrintDebug("ERROR on downloading VIDEO item - ERROR:" + stri(eventCode) + " Video GUID:" + m.currentVideoLoadItem.guid)
				m.asyncVideoDownloadInProgress = false
				if type(feedPlayer) = "roAssociativeArray" and feedPlayer.IsEnabled and type(feedPlayer.feed)="roAssociativeArray" and feedPlayer.feed.id = m.feedId then
					if not feedPlayer.feed.atLoadEnd then
						feedPlayer.LoadNextItem()
					endif
				end if
			else 
				m.asyncVideoDownloadInProgress = false
				if type(feedPlayer) = "roAssociativeArray" and feedPlayer.IsEnabled then
					m.diagnostics.PrintDebug("DOWNLOAD COMPLETE - Video GUID:" + m.currentVideoLoadItem.guid)

					' track download traffic for dynamic playlists
					if feedPlayer.isDynamicPlaylist and type(feedPlayer.stateMachine.bsp.networkingHSM) = "roAssociativeArray" then
						fname = m.videoDownloader.GetUserData()
						checkFile = CreateObject("roReadFile", fname)
						if (checkFile <> invalid) then
							checkFile.SeekToEnd()
							size = checkFile.CurrentPosition()
							checkFile = invalid
							feedPlayer.stateMachine.bsp.networkingHSM.UploadMRSSTrafficDownload(size)
						endif
					endif

					feedPlayer.cacheManager.add (m.currentVideoLoadItem)
					m.currentVideoLoadItem.downloaded = true
					if type(feedPlayer.feed) = "roAssociativeArray" and not feedPlayer.feed.atLoadEnd and feedPlayer.feed.id = m.feedId then
						feedPlayer.LoadNextItem()
					end if
				endif
			end if
		else
			m.diagnostics.PrintDebug("UNKNOWN Status code:" + stri(eventStatus))
		end if
	endif
	
End Sub

'endregion

'region TripleUSB
' TripleUSB state handler function
'
' information that needs to be available to this function includes
'		serial port object for Triple USB
'		serial port object for selected Bose product
'		product name for selected Bose product
'		noise threshold
'		Quiet transition
'		Loud transition
'
' Entry
'		Make GetAmbientNoise call
' Serial Line Event
'		Serial line event - Noise response
'		Parse noise value
'		Compare to noise threshold
'		SetVolume on Bose product
'		If noise value <= noise threshold, execute Quiet transition
'		Else if noise value > noise threshold, execute Loud transition
'
Function STTripleUSBEventHandler(event As Object, stateData As Object) As Object

    stateData.nextState = invalid
    
    if type(event) = "roAssociativeArray" then      ' internal message event

        if IsString(event["EventType"]) then
        
            if event["EventType"] = "ENTRY_SIGNAL" then
            
                m.bsp.diagnostics.PrintDebug(m.id$ + ": entry signal")

				m.bsp.ExecuteMediaStateCommands(m.stateMachine, m)

				m.tripleUSBSerialPort = m.bsp.serial[m.tripleUSBPort$]
				m.boseProductPort = m.bsp.serial[m.boseProductPort$]
				
				m.tripleUSBSerialPort.SendLine("v?")

				' state logging
				m.bsp.logging.WriteStateLogEntry(m.stateMachine, m.id$, "tripleUSB")

				return "HANDLED"
				
            else if event["EventType"] = "EXIT_SIGNAL" then

                m.bsp.diagnostics.PrintDebug(m.id$ + ": exit signal")
            
			endif
			
		endif
		
    else if type(event) = "roStreamLineEvent" then
    
	    m.bsp.diagnostics.PrintDebug("Noise response serial event " + event.GetString())
        
        noiseResponse$ = event.GetString()
        
		m.bsp.logging.WriteEventLogEntry(m.stateMachine, m.id$, "serial", noiseResponse$, "1")

        if len(noiseResponse$) = 5 then
            'Get noise value
			noiseValue% = int(val(mid(noiseResponse$, 3)))
        
            'send out volume command
            if m.SendVolumeCommand(noiseValue%) = "HANDLED" then
                return "HANDLED"
            endif
                       
			if noiseValue% <= m.noiseThreshold% then
				return m.ExecuteTransition(m.quietUserEvent, stateData, "")
			else
				return m.ExecuteTransition(m.loudUserEvent, stateData, "")
			endif
			
        else
        
			m.tripleUSBSerialPort.SendLine("v?")
        
        endif

		return "HANDLED"
    
	endif

    stateData.nextState = m.superState
    return "SUPER"

End Function


Function SendVolumeCommand(noiseValue% As Integer) As Object

	if m.boseProductName$ = "" then
		return ""
	endif
	
    'lookup noise value in our volume table for the product and send vol command
    m.bsp.diagnostics.PrintDebug("SendVolumeCommand: enter") 
    m.bsp.diagnostics.PrintDebug("noiseval " + str(noiseValue%) ) 
                               
    'perform linear interpolation
    volume% = 0

    'protect against no volume table in the BoseProducts xml file
    if type(m.volumeTable) <> "roAssociativeArray" then
        m.bsp.diagnostics.PrintDebug("No Bose Product Volume Table found!" ) 
        return "HANDLED"
    endif

    if noiseValue% >= m.volumeTable.xval3% then
        volume% = m.volumeTable.yval3%
    else if noiseValue% >= m.volumeTable.xval2% then
        if m.volumeTable.xval3% - m.volumeTable.xval2% = 0 then
            m.bsp.diagnostics.PrintDebug("Divide by Zero will occur, check volume table info" )
            return "HANDLED"
        endif                                   
        volume% = (noiseValue% - m.volumeTable.xval2%)*(m.volumeTable.yval3% - m.volumeTable.yval2%)/(m.volumeTable.xval3% - m.volumeTable.xval2%) + m.volumeTable.yval2% 
    else if noiseValue% >= m.volumeTable.xval1% then
        if m.volumeTable.xval2% - m.volumeTable.xval1% = 0 then
            m.bsp.diagnostics.PrintDebug("Divide by Zero will occur, check volume table info" )
            return "HANDLED"
        endif
        volume% = (noiseValue% - m.volumeTable.xval1%)*(m.volumeTable.yval2% - m.volumeTable.yval1%)/(m.volumeTable.xval2% - m.volumeTable.xval1%) + m.volumeTable.yval1% 
    else
        volume% = m.volumeTable.yval1%            
    endif
  
    m.bsp.diagnostics.PrintDebug("volume " + str(volume%) ) 

    ' send volume command to Bose product
    if m.boseProductName$ = "Chihuahua" then
        m.bsp.diagnostics.PrintDebug("Send Volume set command to Chihuahua")
        'ask Ted about this, its giving me a string of 3 digits back with first one as a space?  
        m.boseProductPort.SendLine("vo " + mid(str(volume%),2))
    else if m.boseProductName$ = "Hershey" then
        m.bsp.diagnostics.PrintDebug("Send Volume set command to Hershey")
        'have to subract our volume from 100 since its an attenuation
        volume% = 100 - volume% 
        m.boseProductPort.SendLine("VO CB " + mid(str(volume%),2))
    else if m.boseProductName$ = "Onyx" then
        m.bsp.diagnostics.PrintDebug("Send Volume set command to Onyx")
        'ask Ted about this, its giving me a string of 3 digits back with first one as a space?  
        m.boseProductPort.SendLine("vo " + mid(str(volume%),2))
    else if m.boseProductName$ = "Cinnamon" then
        m.bsp.diagnostics.PrintDebug("Send Volume set command to Cinnamon")
        m.boseProductPort.SendLine("vo " + mid(str(volume%),2))
    else if m.boseProductName$ = "Whippit" then
        m.bsp.diagnostics.PrintDebug("Send Volume set command to Whippit")
        m.boseProductPort.SendLine("vo " + mid(str(volume%),2))
    else if m.boseProductName$ = "Reframe" then
        m.bsp.diagnostics.PrintDebug("Send Volume set command to Reframe")
        m.boseProductPort.SendLine("VS" + mid(str(volume%),2))
    else if m.boseProductName$ = "Max" then
        m.bsp.diagnostics.PrintDebug("Send Volume set command to Max")
        m.boseProductPort.SendLine("SP 102," + mid(str(volume%),2))
    else
        m.bsp.diagnostics.PrintDebug("Unknown Bose Product: " + m.boseProductName$)
        return "HANDLED"
    endif

    return ""

End Function
'endregion

