# 需要以管理员身份运行
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# 配置参数
$InterfaceAlias = "WLAN 2"
$StaticIP = "192.168.8.13"
$PrefixLength = 24

function Get-CurrentMode {
    try {
        $interface = Get-NetIPInterface -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -ErrorAction Stop
        
        if ($interface.Dhcp -eq 'Disabled') {
            $config = Get-NetIPConfiguration -InterfaceAlias $InterfaceAlias -ErrorAction Stop
            $gateway = $config.IPv4DefaultGateway.NextHop
            $dns = $config.DNSServer | Where-Object { $_.AddressFamily -eq 2 } | Select-Object -ExpandProperty ServerAddresses
            
            switch ($gateway) {
                '192.168.8.2' { return '1' }
                '192.168.8.1' { return '2' }
                default { return 'Static(Unknown)' }
            }
        }
        else {
            return '3'
        }
    }
    catch {
        return 'N/A'
    }
}

function Show-Menu {
    $currentMode = Get-CurrentMode
    Clear-Host
    Write-Host "`n网络配置管理系统 [当前模式：$($currentMode)]" -ForegroundColor Magenta
    Write-Host ("-" * 60) -ForegroundColor DarkGray
    
    $menuItems = @(
        @{ Text = "1. 网关模式（网关/DNS → 192.168.8.2）"; Color = ('Cyan', 'Gray')[$currentMode -ne '1'] }
        @{ Text = "2. 默认路由模式（网关/DNS → 192.168.8.1）"; Color = ('Cyan', 'Gray')[$currentMode -ne '2'] }
        @{ Text = "3. DHCP自动获取（IP/DNS自动分配）"; Color = ('Cyan', 'Gray')[$currentMode -ne '3'] }
        @{ Text = "4. 清除DNS缓存"; Color = 'Gray' }
    )

    $menuItems | ForEach-Object {
        Write-Host $_.Text -ForegroundColor $_.Color
    }
    
    Write-Host ("-" * 60) -ForegroundColor DarkGray
    Write-Host "Q. 退出系统"
    Write-Host "`n请选择操作（输入选项编号）：" -ForegroundColor Yellow -NoNewline
}

function Set-StaticNetwork {
    param(
        [Parameter(Mandatory)]
        [string]$Gateway,
        
        [Parameter(Mandatory)]
        [string[]]$DNS
    )
    
    try {
        # 参数有效性验证
        [System.Net.IPAddress]::Parse($StaticIP) | Out-Null
        [System.Net.IPAddress]::Parse($Gateway) | Out-Null
        $DNS | ForEach-Object { [System.Net.IPAddress]::Parse($_) }

        # 清理旧配置
        Get-NetIPAddress -InterfaceAlias $InterfaceAlias `
            -AddressFamily IPv4 `
            -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -eq $StaticIP } |
        Remove-NetIPAddress -Confirm:$false -ErrorAction Stop

        Get-NetRoute -InterfaceAlias $InterfaceAlias `
            -AddressFamily IPv4 `
            -DestinationPrefix '0.0.0.0/0' `
            -ErrorAction SilentlyContinue |
        Remove-NetRoute -Confirm:$false -ErrorAction Stop

        # 设置新IP
        $null = New-NetIPAddress -InterfaceAlias $InterfaceAlias `
            -IPAddress $StaticIP `
            -PrefixLength $PrefixLength `
            -DefaultGateway $Gateway `
            -Confirm:$false `
            -ErrorAction Stop

        # 增强DNS设置
        $maxRetries = 3
        $retryCount = 0
        $dnsParams = @{
            InterfaceAlias  = $InterfaceAlias
            ServerAddresses = $DNS
            Validate        = $true
            ErrorAction     = 'Stop'
        }

        do {
            try {
                Set-DnsClientServerAddress @dnsParams
                break
            }
            catch [Microsoft.Management.Infrastructure.CimException] {
                $retryCount++
                if ($retryCount -ge $maxRetries) {
                    throw "DNS设置最终失败: $($_.Exception.Message) [代码: $($_.Exception.NativeErrorCode)]"
                }

                # 处理特定错误
                switch ($_.Exception.NativeErrorCode) {
                    1168 {
                        # Element not found
                        if (-not (Get-NetAdapter -Name $InterfaceAlias -ErrorAction SilentlyContinue)) {
                            throw "网络适配器 '$InterfaceAlias' 不存在或未启用"
                        }
                        Start-Sleep -Seconds 2
                        continue
                    }
                    87 {
                        # Invalid parameter
                        throw "无效的DNS服务器地址格式: $($DNS -join ', ')"
                    }
                    default {
                        Write-Host "├─ 正在进行第 $retryCount 次重试..." -ForegroundColor DarkYellow
                        Start-Sleep -Seconds 1
                    }
                }
            }
        } while ($true)

        Write-Host "[√] 配置成功生效" -ForegroundColor Green
    }
    catch {
        $errorType = $_.Exception.GetType().Name
        $errorCode = if ($errorType -eq 'CimException') { 
            "[代码: $($_.Exception.NativeErrorCode)]" 
        }
        else { "" }
        
        Write-Host "[!] 配置失败: $($_.Exception.Message) $errorCode" -ForegroundColor Red
        Write-Host "├─ 失败操作: $($_.InvocationInfo.Line.Trim())" -ForegroundColor Cyan
        Write-Host "└─ 建议操作: 请检查以下项目：`n" +
        "   1. 网络适配器名称是否正确`n" +
        "   2. DNS服务器是否可达`n" +
        "   3. 防火墙是否阻止配置更改"
        exit 1
    }
}



function Set-DHCPNetwork {
    try {
        # 启用DHCP
        Set-NetIPInterface -InterfaceAlias $InterfaceAlias -Dhcp Enabled
        Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ResetServerAddresses
        
        # 强制刷新配置
        ipconfig /release | Out-Null
        ipconfig /renew | Out-Null
        Write-Host "[√] 已启用DHCP模式" -ForegroundColor Green
    }
    catch {
        Write-Host "[!] DHCP配置失败: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

function Show-Config {
    try {
        $config = Get-NetIPConfiguration -InterfaceAlias $InterfaceAlias -ErrorAction Stop
        Write-Host "`n当前网络配置：" -ForegroundColor Green
        Write-Host ("-" * 40)
        Write-Host "IP 地址    : $($config.IPv4Address.IPAddress)"
        Write-Host "子网掩码  : $($config.IPv4Address.PrefixLength)"
        Write-Host "网关地址  : $($config.IPv4DefaultGateway.NextHop)"
        Write-Host "DNS 服务器: $($config.DNSServer.ServerAddresses -join ', ')"
    }
    catch {
        Write-Host "[!] 获取配置信息失败" -ForegroundColor Red
    }
}

# 主循环
do {
    Show-Menu
    $choice = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character.ToString().ToLower()
    
    Write-Host $choice -ForegroundColor Cyan
    
    switch ($choice) {
        '1' { 
            Write-Host "`n[ 执行操作 ] 网关模式配置中..." -ForegroundColor White
            Set-StaticNetwork -Gateway "192.168.8.2" -DNS @("192.168.8.2")
            Show-Config
        }
        '2' { 
            Write-Host "`n[ 执行操作 ] 默认路由模式配置中..." -ForegroundColor White
            Set-StaticNetwork -Gateway "192.168.8.1" -DNS @("192.168.8.1")
            Show-Config
        }
        '3' { 
            Write-Host "`n[ 执行操作 ] 切换DHCP模式中..." -ForegroundColor White
            Set-DHCPNetwork
            Show-Config
        }
        '4' { 
            Write-Host "`n[ 执行操作 ] 正在清除DNS缓存..." -ForegroundColor White
            Clear-DnsClientCache 
            Write-Host "[√] DNS缓存已清除" -ForegroundColor Green
        }
        'q' { 
            Write-Host "`n[ 系统退出 ] 感谢使用！" -ForegroundColor Magenta
            exit 
        }
        default { 
            Write-Host "`n[!] 无效输入，请选择有效选项！" -ForegroundColor Red
        }
    }
    
    if ($choice -in '1', '2', '3', '4') {
        Write-Host "`n`n操作完成，3秒后返回主菜单..."
        Start-Sleep -Seconds 3
    }
} while ($true)
