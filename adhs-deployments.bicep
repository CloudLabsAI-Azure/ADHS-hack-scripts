param tagName string
param region string
param workspaceName string
param fhirServiceName string
param storageAccountName string? // Nullable parameter without a default value
param storageAccountConfirm bool = false // Default to false
param smartProxyEnabled bool = false

// Remove unused variables
var managedIdentityType = 'SystemAssigned'

// Create workspace
resource workspace 'Microsoft.HealthcareApis/workspaces@2023-11-01' = {
  name: workspaceName
  location: region
	tags: {
    environmentName: tagName
  }
  properties: {}
}

// Create FHIR service
resource workspaceName_fhirService 'Microsoft.HealthcareApis/workspaces/fhirservices@2023-11-01' = {
  parent: workspace
  name: fhirServiceName
  kind: 'fhir-R4'
  location: region
  tags: {
    environmentName: tagName
  }
  properties: {
    authenticationConfiguration: {
      authority: uri(environment().authentication.loginEndpoint, subscription().tenantId)
      audience: 'https://${workspaceName}-${fhirServiceName}.fhir.azurehealthcareapis.com'
      smartProxyEnabled: smartProxyEnabled
    }
    corsConfiguration: {
      allowCredentials: false
      headers: [
        '*'
      ]
      maxAge: 1440
      methods: [
        'DELETE'
        'GET'
        'OPTIONS'
        'PATCH'
        'POST'
        'PUT'
      ]
      origins: [
        'https://localhost:6001'
      ]
    }
    exportConfiguration: storageAccountConfirm ? {
      storageAccountName: storageAccountName
    } : {}
  }
  identity: {
    type: managedIdentityType
  }
}

// Conditionally create storage account if storageAccountConfirm is true
resource storageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = if (storageAccountConfirm) {
  name: storageAccountName
  location: region
  properties: {
    supportsHttpsTrafficOnly: true
  }
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'Storage'
  tags: {
    environmentName: tagName
  }
}

// Conditionally assign role to storage account if storageAccountConfirm is true
resource storageAccountRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (storageAccountConfirm) {
  scope: storageAccount
  name: guid(storageAccount.id, 'ba92f5b4-2d1') // Ensure unique GUID
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor role
    principalId: workspaceName_fhirService.identity.principalId
  }
}
