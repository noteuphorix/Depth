function Set-UAC {
    $UACPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    
    # 0 = Never Notify
    # 1 = Prompt on Secure Desktop (the dimming effect)
    Set-ItemProperty -Path $UACPath -Name "ConsentPromptBehaviorAdmin" -Value 5
    Set-ItemProperty -Path $UACPath -Name "PromptOnSecureDesktop" -Value 0
    
    Write-Host "UAC configured." -ForegroundColor Green
}