# Turns TPLInk SP Device On/Off!
# uses your TPLnk KAsa credentials to get a login token and get your device list
# locates target device based on device alias
# token is saved in ksasatoken.sav  and reused if valid
# Usage TPLinkSp1OFF.ps1 [0|1] [SP1]
# where 0|1 is the requested state (0 = off)
# Defaults to 0 (Off) and SP1

param
    (
    [int]$requestedState=0,
    [string]$DevName="SP1"
    )

Function Validate-Token {
# Validates current token
   param($testtoken)
    $postParams = @{
        method = "getDeviceList"; 
    }
    $json = ConvertTo-Json -InputObject $postParams -Depth 4
    $res = Invoke-RestMethod -Uri "https://wap.tplinkcloud.com?token=$testtoken" -Method POST -Body $json -ContentType "application/json"
    if ($res.msg -like "token expired"){
        return $false
    } else { 
        return $true 
    }
}
Function Get-KasaToken{
    if (test-path $TokenFile){
        $tok = Get-content $tokenfile
        if (Validate-Token $tok){
            $global:validToken = $true
        }
    } 
    if ($validToken){
        return $tok
    } else {
        $postParams = @{
            method = "login";
            params = @{
                appType = "Kasa_Android";
                cloudUserName = "gmartin@mydomain.com";
                cloudPassword = "xxxxxxxxxxxxx";
                terminalUUID = "2f74aa03-f2f7-4a9b-be7e-a923a1bfeab8"
                };
            }
        $json = ConvertTo-Json -InputObject $postParams -Depth 4
        $res = Invoke-RestMethod -Uri https://wap.tplinkcloud.com -Method POST -Body $json -ContentType "application/json"
        $tok = $res.result.token
        $tok | out-file $TokenFile
        return $tok 
        }
}
Function Get-KasaDevID {
    $postParams = @{
        method = "getDeviceList"; 
    }
    $json = ConvertTo-Json -InputObject $postParams -Depth 4
    $res = Invoke-RestMethod -Uri "https://wap.tplinkcloud.com?token=$token" -Method POST -Body $json -ContentType "application/json"
    if ($res.msg -like "token expired"){
        $global:validToken = $false
    }
    $devices = $res.result.deviceList
    # Each device has its own Alias & deviceID, and app server URL.  
    # We look up the DevID & ApSvrURL using the provided alias
    foreach ($device in $devices){
            if ($device.alias -like $DevName  ){
                $apSvrUrl = $device.appServerUrl
                $lDevID = $device.deviceID
                return $lDevID,$apSvrUrl
            }
    }
    Write-host "Device not found: $DevName"
}
Function Get-DevState {
    #Param ($DevID)
    $postParams = @{
        method = "passthrough"; 
        params = @{
            deviceId = $DevID;
            requestData = "{`"system`":{`"get_sysinfo`":{`"state`":0}}}" 
            }
        }
        $json = ConvertTo-Json -InputObject $postParams -Depth 4
        $res = Invoke-RestMethod -Uri $URI -Method POST -Body $json -ContentType "application/json"
        $Status = convertfrom-json -InputObject $res.result.responsedata
        if ($status.system.get_sysinfo.relay_state -eq 1) {
            Write-Verbose "$Devname is on" 
            return $on
        } else {
            Write-Verbose "$DevName is off"
            return $off 
        }
    }
Function Set-DevState {
    param($desiredState)
    $postParams = @{
        method = "passthrough"; 
        params = @{
            deviceId = $DevID;
            requestData = "{`"system`":{`"set_relay_state`":{`"state`":$desiredState}}}" 
            }
    }
    $json = ConvertTo-Json -InputObject $postParams -Depth 4
    $res = Invoke-RestMethod -Uri $URI  -Method POST -Body $json -ContentType "application/json"
    $Status = convertfrom-json -InputObject $res.result.responsedata
    #error code is return in json as a property of responsedata json in system.command_name.err_code
    if ($status.system.set_relay_state.err_code -ne 0){
        Write-Verbose "Issue changing $DevNAme"
    }
}
# main
$state = @{
    "0" = "off";
    "1" = "on"
}

$Tokenfile = "KasaToken.sav"
$validToken = $false

$token = Get-KasaToken
$devInfo = Get-KasaDevID 
$DevID = $devInfo[0]
$AppSvr = $devInfo[1]
$URI = $AppSvr + "?token=" + $token
echo "Turning $DevNAme $($state."$requestedState")"
Set-DevState $requestedState
Get-DevState > $null


# Reference info
# Device structure
<# Get Device results
{"error_code":0, 
"result": {
    "deviceList":[ {
        "fwVer":"1.2.5 Build 171129 Rel.174814", 
        "deviceName":"Wi-Fi Smart Plug", 
        "status":1, 
        "alias":"SP1", 
        "deviceType":"IOT.SMARTPLUGSWITCH", 
        "appServerUrl":"https://use1-wap.tplinkcloud.com", 
        "deviceModel":"HS100(US)", 
        "deviceMac":"50C7BF07F503", 
        "role":0, 
        "isSameRegion":true, 
        "hwId":"5EACBE93FB9E32ECBE1F1C2ADxxxxxxx", 
        "fwId":"00000000000000000000000000000000", 
        "oemId":"37589AA1F5CACDC53E2914B7760127E5", 
        "deviceId":"800689F445A27D82EE7C50xxxxx9009C177xxxxx", 
        "deviceHwVer":"1.0"}]}}
 #>

