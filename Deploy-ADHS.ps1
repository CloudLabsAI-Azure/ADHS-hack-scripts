# Function to download the Bicep file
Function Download-BicepFile {
    $bicepUrl = "https://raw.githubusercontent.com/CloudLabsAI-Azure/ADHS-hack-scripts/refs/heads/main/adhs-deployments.bicep"  # Replace with actual URL or local path
    $localPath = "deployment.bicep"
    Invoke-WebRequest -Uri $bicepUrl -OutFile $localPath -ErrorAction Stop
    Write-Host "Bicep file downloaded to $localPath"
    return $localPath
}

# Verify if the Azure PowerShell module and Bicep CLI are installed
function Check-AzurePowerShell {
    Write-Host "Checking Azure PowerShell module..." -ForegroundColor Cyan
    try {
        $azmodule = Get-Module Az* -ListAvailable
        if ($azmodule) {
            Write-Host "Azure PowerShell module is installed." -ForegroundColor Green
            return $true
        } else {
            Write-Host "Azure PowerShell module is not installed." -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "Error occurred while checking Azure PowerShell module." -ForegroundColor Red
        return $false
    }
}

# Function to check if Bicep CLI is installed
function Check-BicepCLI {
    Write-Host "Checking Bicep CLI..." -ForegroundColor Cyan
    $bicepVersion = & bicep --version 2>$null
    if ($bicepVersion) {
        Write-Host "Bicep CLI is installed. Version: $bicepVersion" -ForegroundColor Green
        return $true
    } else {
        Write-Host "Bicep CLI is not installed." -ForegroundColor Red
        return $false
    }
}

# Function to list all Azure subscriptions
Function List-AzureSubscriptions {
    Write-Host "Fetching the list of Azure subscriptions..." -ForegroundColor Cyan
    try {
        # Retrieve all subscriptions available to the authenticated account
        $subscriptions = Get-AzSubscription

        # Display the list of subscriptions
        if ($subscriptions.Count -gt 0) {
            Write-Host "Available Subscriptions:" -ForegroundColor Green
            $subscriptions | ForEach-Object {
                Write-Host "$($_.Name) ($($_.Id))"
            }
        } else {
            Write-Host "No subscriptions found for the authenticated account." -ForegroundColor Red
        }
    } catch {
        Write-Host "Error fetching subscriptions: $_" -ForegroundColor Red
    }
}

# Function to select a subscription
Function Select-AzureSubscription {
    Write-Host "Fetching available subscriptions..." -ForegroundColor Cyan
    $subscriptions = Get-AzSubscription

    if ($subscriptions.Count -eq 1) {
        $defaultSubscription = $subscriptions[0]
        Write-Host "Only one subscription found. Selecting the default subscription: $($defaultSubscription.Name)" -ForegroundColor Green
        Set-AzContext -SubscriptionId $defaultSubscription.Id
    } else {
        Write-Host "Multiple subscriptions found. Please select one:" -ForegroundColor Cyan

        # Display subscriptions with indexes
        for ($i = 0; $i -lt $subscriptions.Count; $i++) {
            Write-Host "[$i] $($subscriptions[$i].Name) ($($subscriptions[$i].Id))"
        }

        # Get user selection
        $selection = Read-Host "Enter the number corresponding to your choice"
        if ($selection -match "^\d+$" -and $selection -ge 0 -and $selection -lt $subscriptions.Count) {
            $selectedSubscription = $subscriptions[$selection]
            Set-AzContext -SubscriptionId $selectedSubscription.Id
            Write-Host "Subscription set to: $($selectedSubscription.Name)" -ForegroundColor Green
        } else {
            Write-Host "Invalid selection. Please try again." -ForegroundColor Red
            Exit
        }
    }
}

# Function to list and select a resource group
Function List-And-Select-ResourceGroup {
    Write-Host "Fetching the list of resource groups..." -ForegroundColor Cyan
    try {
        $resourceGroups = Get-AzResourceGroup

        if ($resourceGroups.Count -gt 0) {
            Write-Host "Available Resource Groups:" -ForegroundColor Green

            # Display resource groups with indexes
            for ($i = 0; $i -lt $resourceGroups.Count; $i++) {
                Write-Host "[$i] $($resourceGroups[$i].ResourceGroupName)"
            }

            # Get user selection
            $selection = Read-Host "Enter the number corresponding to your choice"
            if ($selection -match "^\d+$" -and $selection -ge 0 -and $selection -lt $resourceGroups.Count) {
                $selectedResourceGroup = $resourceGroups[$selection]
                Write-Host "Selected Resource Group: $($selectedResourceGroup.ResourceGroupName)" -ForegroundColor Green
                return $selectedResourceGroup.ResourceGroupName
            } else {
                Write-Host "Invalid selection. Please try again." -ForegroundColor Red
                Exit
            }
        } else {
            Write-Host "No resource groups found in the current subscription." -ForegroundColor Red
            return $null
        }
    } catch {
        Write-Host "Error fetching resource groups: $_" -ForegroundColor Red
        return $null
    }
}

# Main script logic
$azurePowerShellInstalled = Check-AzurePowerShell
$bicepCLIInstalled = Check-BicepCLI

if (-not $azurePowerShellInstalled) {
    Write-Host "Do you want to install the Azure PowerShell module now? (Y/N)" -ForegroundColor Yellow
    $installAzure = Read-Host
    if ($installAzure -eq 'Y') {
        Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force
        Write-Host "Azure PowerShell module installed successfully." -ForegroundColor Green
    } else {
        Write-Host "Skipping Azure PowerShell module installation." -ForegroundColor Yellow
    }
}

if (-not $bicepCLIInstalled) {
    Write-Host "Do you want to install the Bicep CLI now? (Y/N)" -ForegroundColor Yellow
    $installBicep = Read-Host
    if ($installBicep -eq 'Y') {
        # Install Bicep CLI using Azure CLI
        az bicep install
        Write-Host "Bicep CLI installed successfully." -ForegroundColor Green
    } else {
        Write-Host "Skipping Bicep CLI installation." -ForegroundColor Yellow
    }
}

# Login to Azure
Connect-AzAccount

# List available subscriptions
List-AzureSubscriptions

# Select a subscription
Select-AzureSubscription

# Step 1: Get user input for parameters
$tagName = Read-Host "Enter the environment name tag"
$region = Read-Host "Enter the Azure region"
$workspaceName = Read-Host "Enter the name for the workspace"
$fhirServiceName = Read-Host "Enter the name for the FHIR service"

# Prompt for storage account confirmation and convert input to boolean
$storageAccountConfirmInput = Read-Host "Would you like to include and deploy a storage account for export configuration? Enter 'true' or 'false'"

# Convert input to boolean
$storageAccountConfirm = $false
if ($storageAccountConfirmInput -eq "true") {
    $storageAccountConfirm = $true
} elseif ($storageAccountConfirmInput -eq "false") {
    $storageAccountConfirm = $false
} else {
    Write-Host "Invalid input for storage account confirmation. Defaulting to false."
}

# Optional storage account prompts if $storageAccountConfirm is true
if ($storageAccountConfirm -eq $true) {
    Write-Host "Prompting for storage account prefix."
    $storageAccountPrefix = Read-Host "Enter the prefix for the storage account"

    # Ensure the storage account name is unique by appending a random suffix or timestamp
    $uniqueSuffix = Get-Random -Minimum 1000 -Maximum 9999
    $storageAccountName = $storageAccountPrefix + $uniqueSuffix

    Write-Host "Generated unique storage account name: $storageAccountName"
} else {
    Write-Host "Skipping storage account prompt."
    $storageAccountName = $null
}

# Step 2: Resource group handling
$existingRG = Read-Host "Would you like to deploy in an existing resource group? Enter 'yes' or 'no':"
if ($existingRG -eq "yes") {
    $resourceGroupName = List-And-Select-ResourceGroup
    if (-not $resourceGroupName) {
        Write-Host "No resource group selected. Exiting script." -ForegroundColor Red
        Exit
    }
} else {
    $resourceGroupName = Read-Host "Enter the name for the new resource group"
    New-AzResourceGroup -Name $resourceGroupName -Location $region
    Write-Host "Resource group '$resourceGroupName' created in region '$region'."
}

# Step 3: Prepare parameters for the Bicep deployment
$parameters = @{
    tagName = $tagName
    region = $region
    workspaceName = $workspaceName
    fhirServiceName = $fhirServiceName
    storageAccountConfirm = $storageAccountConfirm
}

# Add storage account name if required
if ($storageAccountConfirm -eq $true) {
    $parameters["storageAccountName"] = $storageAccountName
}

# Convert the parameters hashtable to an object for PowerShell deployment
$params = $parameters

# Debug output to verify parameters
Write-Host "Parameters: $($params | ConvertTo-Json -Depth 5)"

# Step 4: Download Bicep file and deploy using New-AzResourceGroupDeployment
$bicepFilePath = Download-BicepFile

$deploymentResult = New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $bicepFilePath -TemplateParameterObject $params

# Check the result of the deployment
if ($deploymentResult.ProvisioningState -eq 'Succeeded') {
    Write-Host "Deployment succeeded! at resource group " $deploymentResult.ResourceGroupName -ForegroundColor Green 
} else {
    Write-Host "Deployment failed. Status: $($deploymentResult.ProvisioningState)"
}
