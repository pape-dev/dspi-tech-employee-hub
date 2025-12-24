<#
.SYNOPSIS
    Script de déploiement d'infrastructure Azure Web App Pro.
.DESCRIPTION
    Version corrigée pour une compatibilité totale avec Azure Cloud Shell.
#>

# --- 1. CONFIGURATION TOUT-EN-UN ---
$config = @{
    RGName      = "rg-node-prod-norway"
    Location    = "norwayeast"
    PlanName    = "asp-node-linux-premium"
    AppName     = "webapp-node-$(Get-Random -Minimum 1000 -Maximum 9999)"
    SkuTier     = "Basic"
    SkuSize     = "B1"
    Runtime     = "NODE|20-lts"
}

$tags = @{
    Environment = "Production"
    Project     = "Project-Azure-dspi"
}

Write-Host "`n[1/5] Préparation du Groupe de Ressources..." -ForegroundColor Magenta
if (!(Get-AzResourceGroup -Name $config.RGName -ErrorAction SilentlyContinue)) {
    New-AzResourceGroup -Name $config.RGName -Location $config.Location -Tag $tags -Force | Out-Null
}

# --- 2. MONITORING ---
Write-Host "[2/5] Configuration du monitoring (App Insights)..." -ForegroundColor Cyan
$appInsights = New-AzApplicationInsights -ResourceGroupName $config.RGName `
    -Name "$($config.AppName)-insights" -Location $config.Location -Force

# --- 3. PLAN ET WEB APP ---
Write-Host "[3/5] Création des services App Service Linux..." -ForegroundColor Cyan
$plan = New-AzAppServicePlan -Name $config.PlanName -ResourceGroupName $config.RGName `
    -Location $config.Location -Tier $config.SkuTier -NumberofWorkers 1 `
    -WorkerSize "Small" -Linux -ErrorAction Stop

$webApp = New-AzWebApp -Name $config.AppName -ResourceGroupName $config.RGName `
    -Location $config.Location -AppServicePlan $config.PlanName

# --- 4. CONFIGURATION SÉCURITÉ ET RUNTIME ---
Write-Host "[4/5] Application de la configuration système..." -ForegroundColor Cyan
# On modifie l'objet WebApp
$webApp.SiteConfig.LinuxFxVersion = $config.Runtime
$webApp.HttpsOnly = $true
$webApp.SiteConfig.MinTlsVersion = "1.2"

# Action 1 : On enregistre les modifications système
Set-AzWebApp -WebApp $webApp | Out-Null

# --- 5. CONFIGURATION DES APP SETTINGS ---
Write-Host "[5/5] Injection des variables d'environnement..." -ForegroundColor Cyan
$appSettings = @{
    "NODE_ENV"                              = "production"
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = $appInsights.InstrumentationKey
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = $appInsights.ConnectionString
}

# Action 2 : On enregistre les AppSettings séparément (Méthode 100% compatible)
Set-AzWebApp -ResourceGroupName $config.RGName -Name $config.AppName -AppSettings $appSettings | Out-Null

# --- 6. RAPPORT FINAL ---
Write-Host "`n=========================================================" -ForegroundColor Green
Write-Host "             INFRASTRUCTURE PRÊTE AU DÉPLOIEMENT" -ForegroundColor Green
Write-Host "========================================================="
Write-Host " URL Publique    : https://$($config.AppName).azurewebsites.net"
Write-Host " Groupe Ress.    : $($config.RGName)"
Write-Host " Runtime         : $($config.Runtime)"
Write-Host "========================================================="
