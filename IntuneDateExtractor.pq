let
    resource = "https://graph.microsoft.com",
    tokenUrl = "https://login.microsoftonline.com/" & #"Tenant ID" & "/oauth2/v2.0/token",
    tokenResponse = Json.Document(Web.Contents(tokenUrl,
    [
        Content = Text.ToBinary(Uri.BuildQueryString(
            [
                client_id = #"Client ID",
                scope = resource & "/.default",
                grant_type = "client_credentials",
                client_secret = #"Client Secret"
            ]
        )),
        Headers = [#"Content-Type" = "application/x-www-form-urlencoded"],
        ManualStatusHandling = {400, 401, 403, 404}
    ])),
    token = tokenResponse[access_token],
    
    // Fetch user information
    usersUrl = "https://graph.microsoft.com/beta/users?$select=id,displayName,userPrincipalName,mail,city,department",
    usersData = Json.Document(Web.Contents(usersUrl, 
        [Headers = [Authorization = "Bearer " & token], ManualStatusHandling = {400, 401, 403, 404}]
    )),
    
    // Fetch device information from Intune
    devicesUrl = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?$select=id,userId,deviceName,operatingSystem,osVersion,lastSyncDateTime,serialNumber,imei",
    devicesData = Json.Document(Web.Contents(devicesUrl, 
        [Headers = [Authorization = "Bearer " & token], ManualStatusHandling = {400, 401, 403, 404}]
    )),
    
    // Convert to tables
    usersTable = Table.FromRecords(usersData[value]),
    devicesTable = Table.FromRecords(devicesData[value]),
    
    // Rename id column in devicesData
    devicesDataRenamed = Table.RenameColumns(devicesTable, {{"id", "deviceId"}}),
    
    // Combine user and device information
    combinedData = Table.NestedJoin(
        usersTable,
        {"id"},
        devicesDataRenamed,
        {"userId"},
        "Devices",
        JoinKind.LeftOuter
    ),
    expandedData = Table.ExpandTableColumn(combinedData, "Devices", {"deviceId", "deviceName", "operatingSystem", "osVersion", "lastSyncDateTime", "serialNumber", "imei"})
in
    expandedData