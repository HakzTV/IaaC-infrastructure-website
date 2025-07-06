@allowed([
  'westeurope'
  'eastus'
  'northeurope'
  'swedencentral'
  'germanywestcentral'
  'southafricanorth'
])
param metricLocation string = 'westeurope'

@allowed([
  'westeurope'
  'uksouth'
  'northeurope'
  'eastus'
  'swedencentral'
])
param queryLocation string = 'westeurope'

param appName string
param appServiceResourceId string // Microsoft.Web/sites
param appServicePlanResourceId string // Microsoft.Web/serverfarms
param logAnalyticsWorkspaceId string
param ignoreDataBefore string = utcNow()

// 🚨 CPU Alert
resource cpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${appName}-cpu-alert'
  location: metricLocation
  properties: {
    description: 'Alert when CPU usage > 80%'
    severity: 2
    enabled: true
    scopes: [ appServicePlanResourceId ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          metricName: 'CpuPercentage'
          metricNamespace: 'Microsoft.Web/serverfarms'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
        }
      ]
    }
    autoMitigate: true
    targetResourceType: 'Microsoft.Web/serverfarms'
  }
}

// 🚨 Memory Alert
resource memoryAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${appName}-memory-alert'
  location: metricLocation
  properties: {
    description: 'Alert when memory > 80%'
    severity: 2
    enabled: true
    scopes: [ appServicePlanResourceId ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria'
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          metricName: 'MemoryWorkingSet'
          metricNamespace: 'Microsoft.Web/serverfarms'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
        }
      ]
    }
    autoMitigate: true
    targetResourceType: 'Microsoft.Web/serverfarms'
  }
}

// 🚨 HTTP 500 Error Alert (Query)
resource http500Alert 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = {
  name: '${appName}-http500-alert'
  location: queryLocation
  properties: {
    description: 'Alert when HTTP 500s exceed 5 per 5 mins'
    enabled: true
    source: {
      query: '''
        AppRequests
        | where ResultCode == "500"
        | summarize count() by bin(TimeGenerated, 5m)
        | where count_ > 5
      '''
      dataSourceId: logAnalyticsWorkspaceId
      queryType: 'ResultCount'
      authorizedResources: []
    }
    schedule: {
      frequencyInMinutes: 5
      timeWindowInMinutes: 5
    }
    action: {
      severity: 2
    }
    scopes: [
      logAnalyticsWorkspaceId
    ]
  }
}

// 🚨 Request Anomaly Detection
resource anomalyAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${appName}-anomaly-requests'
  location: metricLocation
  properties: {
    description: 'Anomaly detection on HTTP requests'
    severity: 3
    enabled: true
    scopes: [ appServiceResourceId ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          criterionType: 'DynamicThresholdCriterion'
          metricName: 'Requests'
          metricNamespace: 'Microsoft.Web/sites'
          sensitivity: 'Medium'
          direction: 'Both'
          ignoreDataBefore: ignoreDataBefore
          timeAggregation: 'Total'
        }
      ]
    }
    autoMitigate: true
    targetResourceType: 'Microsoft.Web/sites'
  }
}
