# Carregar variáveis de ambiente de um arquivo .env
$envPath = ".\.env"
Get-Content $envPath | ForEach-Object {
    $key, $value = $_ -split '=', 2
    Set-Item -Path env:$key -Value $value
}

$url_email = "https://apisiad-production.up.railway.app/reset/add-request"
$headers = @{
    'Content-Type' = 'application/json'
}

Function New-MilitaryRegistration {
    Start-Sleep -Seconds 10  # Simula a execução do robô
    return @{
        "status" = "OK"
        "message" = "Reset de senha realizado com sucesso. Entre com a senha padrão 'snhrcf' e redefina. Em caso de duvidas ligue para (31)312-3456"
    }
}

Function Connect-To-WebSocket {
    $secret_code = $env:SECRETCODE
    $uri = "wss://apisiad-production.up.railway.app/reset/ws/resetkey?token=$secret_code"
    $running = $true

    # Thread para monitorar a entrada do teclado
    $keyboardTask = [System.Threading.Tasks.Task]::Run([Action]{
        do {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq 'Escape') {
                $running = $false
            }
        } while ($running)
    })

    Write-Host "Connecting to $uri..."

    while ($running) {
        $WebSocket = $null
        try {
            $WebSocket = [System.Net.WebSockets.ClientWebSocket]::new()
            $WebSocket.ConnectAsync($uri, [System.Threading.CancellationToken]::None).Wait()
            Write-Host "Connected. Listening for messages..."

            $bufferSize = 2048
            $byteArray = New-Object Byte[] $bufferSize
            $buffer = New-Object System.ArraySegment[byte] $byteArray, 0, $bufferSize

            while ($running) {
                $result = $WebSocket.ReceiveAsync($buffer, [System.Threading.CancellationToken]::None).Result
                $message = [System.Text.Encoding]::UTF8.GetString($buffer.Array, 0, $result.Count)
                $object = $message | ConvertFrom-Json
                Write-Host "Received message: $($object.email)"
                $response_mail = New-MilitaryRegistration
                Write-Host @"
                    token: $secret_code
                    email: $($object.email)
                    message: $($response_mail.message)
"@
                $response_body = @{
                    "token" = $secret_code
                    "email" = $object.email
                    "message" = $response_mail.message
                }
                Invoke-RestMethod -Method Post -Uri $url_email -Body ($response_body | ConvertTo-Json) -Headers $headers
                $WebSocket.SendAsync([System.Text.Encoding]::UTF8.GetBytes($response_mail.status), [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [System.Threading.CancellationToken]::None).Wait()
                Write-Host "Sent message: $($response_mail.status)"
            }
        } catch {
            Write-Host "Failed to connect or error occurred: $_"
            Start-Sleep -Seconds 5  # Espera antes de tentar reconectar
        } finally {
            if ($null -ne $WebSocket -and $WebSocket.State -eq "Open") {
                $WebSocket.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "Closing", [System.Threading.CancellationToken]::None).Wait()
                Write-Host "WebSocket closed."
            }
        }
    }
    $keyboardTask.Wait()
}

Connect-To-WebSocket
