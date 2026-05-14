// Sample workload resource consumed by R006 (IaC coverage).
// Any live resource in `aks01day2-rg` whose name does not appear in this folder
// will be flagged as not-in-IaC.

param location string = resourceGroup().location
param clusterName string = 'aks01'

resource aks 'Microsoft.ContainerService/managedClusters@2024-05-01' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: clusterName
    agentPoolProfiles: [
      {
        name: 'sysnp'
        count: 3
        vmSize: 'Standard_D4s_v5'
        mode: 'System'
      }
    ]
  }
}
