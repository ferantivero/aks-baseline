targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('Location of the regional resources.')
param location string

@description('Name of the AKS cluster.')
param clusterName string

@description('Resource ID of the Log Analytics workspace.')
param logAnalyticsWorkspaceResourceId string

/*** VARIABLES ***/

var kubernetesAlertRuleGroupName = 'KubernetesAlert-RecommendedMetricAlerts${clusterName}'
var kubernetesAlertRuleGroupDescription = 'Kubernetes Alert RuleGroup-RecommendedMetricAlerts - 0.1'

/*** EXISTING RESOURCES ***/

resource mc 'Microsoft.ContainerService/managedClusters@2024-03-02-preview' existing = {
  name: clusterName
}

resource amw 'Microsoft.Monitor/accounts@2023-04-03' existing = {
  name: 'amw-${mc.name}'
}

/*** RESOURCES ***/

resource alaRgRecommendations 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: 'AllAzureAdvisorAlert'
  location: 'Global'
  properties: {
    scopes: [
      resourceGroup().id
    ]
    condition: {
      allOf: [
        {
          field: 'category'
          equals: 'Recommendation'
        }
        {
          field: 'operationName'
          equals: 'Microsoft.Advisor/recommendations/available/action'
        }
      ]
    }
    actions: {
      actionGroups: []
    }
    enabled: true
    description: 'All azure advisor alerts'
  }
}

resource kubernetesAlertRuleGroupName_Pod_level 'Microsoft.AlertsManagement/prometheusRuleGroups@2023-03-01' = {
  name: '${kubernetesAlertRuleGroupName}-Pod-level'
  location: location
  properties: {
    description: kubernetesAlertRuleGroupDescription
    scopes: [
      amw.id
      mc.id
    ]
    clusterName: mc.name
    interval: 'PT1M'
    rules: [
      {
        alert: 'KubeJobStale'
        expression: 'sum by(namespace,cluster)(kube_job_spec_completions{job="kube-state-metrics"}) - sum by(namespace,cluster)(kube_job_status_succeeded{job="kube-state-metrics"})  > 0 '
        for: 'PT360M'
        annotations: {
          description: 'Number of stale jobs older than six hours is greater than 0. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts).'
        }
        enabled: true
        severity: 4
        resolveConfiguration: {
          autoResolved: true
          timeToResolve: 'PT15M'
        }
        labels: {
          severity: 'warning'
        }
        actions: []
      }
      {
        alert: 'KubeContainerAverageCPUHigh'
        expression: 'sum (rate(container_cpu_usage_seconds_total{image!="", container!="POD"}[5m])) by (pod,cluster,container,namespace) / sum(container_spec_cpu_quota{image!="", container!="POD"}/container_spec_cpu_period{image!="", container!="POD"}) by (pod,cluster,container,namespace) > .95'
        for: 'PT5M'
        annotations: {
          description: 'Average CPU usage per container is greater than 95%. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts).'
        }
        enabled: true
        severity: 4
        resolveConfiguration: {
          autoResolved: true
          timeToResolve: 'PT15M'
        }
        labels: {
          severity: 'warning'
        }
        actions: []
      }
      {
        alert: 'KubeContainerAverageMemoryHigh'
        expression: 'avg by (namespace, controller, container, cluster)(((container_memory_working_set_bytes{container!="", image!="", container!="POD"} / on(namespace,cluster,pod,container) group_left kube_pod_container_resource_limits{resource="memory", node!=""})*on(namespace, pod, cluster) group_left(controller) label_replace(kube_pod_owner, "controller", "$1", "owner_name", "(.*)")) > .95)'
        for: 'PT10M'
        annotations: {
          description: 'Average Memory usage per container is greater than 95%. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts).'
        }
        enabled: true
        severity: 4
        resolveConfiguration: {
          autoResolved: true
          timeToResolve: 'PT10M'
        }
        labels: {
          severity: 'warning'
        }
        actions: []
      }
      {
        alert: 'KubePodFailedState'
        expression: 'sum by (cluster, namespace, controller) (kube_pod_status_phase{phase="failed"} * on(namespace, pod, cluster) group_left(controller) label_replace(kube_pod_owner, "controller", "$1", "owner_name", "(.*)"))  > 0'
        for: 'PT5M'
        annotations: {
          description: 'Number of pods in failed state are greater than 0. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts).'
        }
        enabled: true
        severity: 4
        resolveConfiguration: {
          autoResolved: true
          timeToResolve: 'PT15M'
        }
        labels: {
          severity: 'warning'
        }
        actions: []
      }
      {
        alert: 'KubePVUsageHigh'
        expression: 'avg by (namespace, controller, container, cluster)(((kubelet_volume_stats_used_bytes{job="kubelet"} / on(namespace,cluster,pod,container) group_left kubelet_volume_stats_capacity_bytes{job="kubelet"}) * on(namespace, pod, cluster) group_left(controller) label_replace(kube_pod_owner, "controller", "$1", "owner_name", "(.*)"))) > .8'
        for: 'PT15M'
        annotations: {
          description: 'Average PV usage on pod {{ $labels.pod }} in container {{ $labels.container }}  is greater than 80%. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts).'
        }
        enabled: true
        severity: 3
        resolveConfiguration: {
          autoResolved: true
          timeToResolve: 'PT10M'
        }
        labels: {
          severity: 'warning'
        }
        actions: []
      }
      {
        alert: 'KubePodReadyStateLow'
        expression: 'sum by (cluster,namespace,deployment)(kube_deployment_status_replicas_ready) / sum by (cluster,namespace,deployment)(kube_deployment_spec_replicas) <.8 or sum by (cluster,namespace,deployment)(kube_daemonset_status_number_ready) / sum by (cluster,namespace,deployment)(kube_daemonset_status_desired_number_scheduled) <.8 '
        for: 'PT5M'
        annotations: {
          description: 'Ready state of pods is less than 80%. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts).'
        }
        enabled: true
        severity: 4
        resolveConfiguration: {
          autoResolved: true
          timeToResolve: 'PT15M'
        }
        labels: {
          severity: 'warning'
        }
        actions: []
      }
      {
        alert: 'KubePodContainerRestart'
        expression: 'sum by (namespace, controller, container, cluster)(increase(kube_pod_container_status_restarts_total{job="kube-state-metrics"}[1h])* on(namespace, pod, cluster) group_left(controller) label_replace(kube_pod_owner, "controller", "$1", "owner_name", "(.*)")) > 0'
        for: 'PT15M'
        annotations: {
          description: 'Pod container restarted in the last 1 hour. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts).'
        }
        enabled: true
        severity: 4
        resolveConfiguration: {
          autoResolved: true
          timeToResolve: 'PT10M'
        }
        labels: {
          severity: 'warning'
        }
        actions: []
      }
      {
        alert: 'KubePodCrashLooping'
        expression: 'max_over_time(kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff", job="kube-state-metrics"}[5m]) >= 1'
        for: 'PT15M'
        annotations: {
          description: '{{ $labels.namespace }}/{{ $labels.pod }} ({{ $labels.container }}) in {{ $labels.cluster}} is restarting {{ printf "%.2f" $value }} / second. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts).'
        }
        enabled: true
        severity: 4
        resolveConfiguration: {
          autoResolved: true
          timeToResolve: 'PT10M'
        }
        labels: {
          severity: 'warning'
        }
        actions: []
      }
      {
        alert: 'KubePodNotReadyByController'
        expression: 'sum by (namespace, controller, cluster) (max by(namespace, pod, cluster) (kube_pod_status_phase{job="kube-state-metrics", phase=~"Pending|Unknown"}  ) * on(namespace, pod, cluster) group_left(controller)label_replace(kube_pod_owner,"controller","$1","owner_name","(.*)")) > 0'
        for: 'PT15M'
        annotations: {
          description: '{{ $labels.namespace }}/{{ $labels.pod }} in {{ $labels.cluster}} by controller is not ready. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts).'
        }
        enabled: true
        severity: 3
        resolveConfiguration: {
          autoResolved: true
          timeToResolve: 'PT10M'
        }
        labels: {
          severity: 'warning'
        }
        actions: []
      }
      {
        alert: 'KubeStatefulSetGenerationMismatch'
        expression: 'kube_statefulset_status_observed_generation{job="kube-state-metrics"} != kube_statefulset_metadata_generation{job="kube-state-metrics"}'
        for: 'PT15M'
        annotations: {
          description: 'StatefulSet generation for {{ $labels.namespace }}/{{ $labels.statefulset }} does not match, this indicates that the StatefulSet has failed but has not been rolled back. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts).'
        }
        enabled: true
        severity: 3
        resolveConfiguration: {
          autoResolved: true
          timeToResolve: 'PT10M'
        }
        labels: {
          severity: 'warning'
        }
        actions: []
      }
      {
        alert: 'KubeJobFailed'
        expression: 'kube_job_failed{job="kube-state-metrics"}  > 0'
        for: 'PT15M'
        annotations: {
          description: 'Job {{ $labels.namespace }}/{{ $labels.job_name }} in {{ $labels.cluster}} failed to complete. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts).'
        }
        enabled: true
        severity: 3
        resolveConfiguration: {
          autoResolved: true
          timeToResolve: 'PT10M'
        }
        labels: {
          severity: 'warning'
        }
        actions: []
      }
      {
        alert: 'KubeletPodStartUpLatencyHigh'
        expression: 'histogram_quantile(0.99, sum(rate(kubelet_pod_worker_duration_seconds_bucket{job="kubelet"}[5m])) by (cluster, instance, le)) * on(cluster, instance) group_left(node) kubelet_node_name{job="kubelet"} > 60'
        for: 'PT10M'
        annotations: {
          description: 'Kubelet Pod startup latency is too high. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts).'
        }
        enabled: true
        severity: 4
        resolveConfiguration: {
          autoResolved: true
          timeToResolve: 'PT10M'
        }
        labels: {
          severity: 'warning'
        }
        actions: []
      }
      {
        alert: 'KubeDeploymentReplicasMismatch'
        expression: '(  kube_deployment_spec_replicas{job="kube-state-metrics"}    >  kube_deployment_status_replicas_available{job="kube-state-metrics"}) and (  changes(kube_deployment_status_replicas_updated{job="kube-state-metrics"}[10m])    ==  0)'
        for: 'PT15M'
        annotations: {
          description: 'Deployment {{ $labels.namespace }}/{{ $labels.deployment }} in {{ $labels.cluster}} replica mismatch. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts).'
        }
        enabled: true
        severity: 4
        resolveConfiguration: {
          autoResolved: true
          timeToResolve: 'PT15M'
        }
        labels: {
          severity: 'warning'
        }
        actions: []
      }
      {
        alert: 'KubeStatefulSetReplicasMismatch'
        expression: '(  kube_statefulset_status_replicas_ready{job="kube-state-metrics"}    !=  kube_statefulset_status_replicas{job="kube-state-metrics"}) and (  changes(kube_statefulset_status_replicas_updated{job="kube-state-metrics"}[10m])    ==  0)'
        for: 'PT15M'
        annotations: {
          description: 'StatefulSet {{ $labels.namespace }}/{{ $labels.statefulset }} in {{ $labels.cluster}} replica mismatch. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts).'
        }
        enabled: true
        severity: 4
        resolveConfiguration: {
          autoResolved: true
          timeToResolve: 'PT10M'
        }
        labels: {
          severity: 'warning'
        }
        actions: []
      }
      {
        alert: 'KubeHpaReplicasMismatch'
        expression: '(kube_horizontalpodautoscaler_status_desired_replicas{job="kube-state-metrics"}  !=kube_horizontalpodautoscaler_status_current_replicas{job="kube-state-metrics"})  and(kube_horizontalpodautoscaler_status_current_replicas{job="kube-state-metrics"}  >kube_horizontalpodautoscaler_spec_min_replicas{job="kube-state-metrics"})  and(kube_horizontalpodautoscaler_status_current_replicas{job="kube-state-metrics"}  <kube_horizontalpodautoscaler_spec_max_replicas{job="kube-state-metrics"})  and changes(kube_horizontalpodautoscaler_status_current_replicas{job="kube-state-metrics"}[15m]) == 0'
        for: 'PT15M'
        annotations: {
          description: 'Horizontal Pod Autoscaler in {{ $labels.cluster}} has not matched the desired number of replicas for longer than 15 minutes. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts).'
        }
        enabled: true
        severity: 4
        resolveConfiguration: {
          autoResolved: true
          timeToResolve: 'PT15M'
        }
        labels: {
          severity: 'warning'
        }
        actions: []
      }
      {
        alert: 'KubeHpaMaxedOut'
        expression: 'kube_horizontalpodautoscaler_status_current_replicas{job="kube-state-metrics"}  ==kube_horizontalpodautoscaler_spec_max_replicas{job="kube-state-metrics"}'
        for: 'PT15M'
        annotations: {
          description: 'Horizontal Pod Autoscaler in {{ $labels.cluster}} has been running at max replicas for longer than 15 minutes. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts).'
        }
        enabled: true
        severity: 4
        resolveConfiguration: {
          autoResolved: true
          timeToResolve: 'PT15M'
        }
        labels: {
          severity: 'warning'
        }
        actions: []
      }
    ]
  }
}

resource kubernetesAlertRuleGroupName_Node_level 'Microsoft.AlertsManagement/prometheusRuleGroups@2023-03-01' = {
  name: '${kubernetesAlertRuleGroupName}-Node-level'
  location: location
  properties: {
    description: kubernetesAlertRuleGroupDescription
    scopes: [
      amw.id
      mc.id
    ]
    clusterName: mc.name
    interval: 'PT1M'
    rules: [
      {
        alert: 'KubeNodeUnreachable'
        expression: '(kube_node_spec_taint{job="kube-state-metrics",key="node.kubernetes.io/unreachable",effect="NoSchedule"} unless ignoring(key,value) kube_node_spec_taint{job="kube-state-metrics",key=~"ToBeDeletedByClusterAutoscaler|cloud.google.com/impending-node-termination|aws-node-termination-handler/spot-itn"}) == 1'
        for: 'PT15M'
        annotations: {
          description: '{{ $labels.node }} in {{ $labels.cluster}} is unreachable and some workloads may be rescheduled. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/node-level-recommended-alerts).'
        }
        enabled: true
        severity: 3
        resolveConfiguration: {
          autoResolved: true
          timeToResolve: 'PT10M'
        }
        labels: {
          severity: 'warning'
        }
        actions: []
      }
      {
        alert: 'KubeNodeReadinessFlapping'
        expression: 'sum(changes(kube_node_status_condition{status="true",condition="Ready"}[15m])) by (cluster, node) > 2'
        for: 'PT15M'
        annotations: {
          description: 'The readiness status of node {{ $labels.node }} in {{ $labels.cluster}} has changed more than 2 times in the last 15 minutes. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/node-level-recommended-alerts).'
        }
        enabled: true
        severity: 3
        resolveConfiguration: {
          autoResolved: true
          timeToResolve: 'PT10M'
        }
        labels: {
          severity: 'warning'
        }
        actions: []
      }
      {
        alert: 'KubeNodeDiskUsageHigh'
        expression: '100 - ((node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100) > 80'
        for: 'PT15M'
        annotations: {
          description: 'The disk usage on node {{ $labels.instance }} in {{ $labels.job }} has exceeded 80% and current usage is {{ $value | humanizePercentage }}%). For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/node-level-recommended-alerts).'
        }
        enabled: true
        severity: 3
        resolveConfiguration: {
          autoResolved: true
          timeToResolve: 'PT10M'
        }
        labels: {
          severity: 'warning'
        }
        actions: []
      }
    ]
  }
}

resource kubernetesAlertRuleGroupName_Cluster_level 'Microsoft.AlertsManagement/prometheusRuleGroups@2023-03-01' = {
  name: '${kubernetesAlertRuleGroupName}-Cluster-level'
  location: location
  properties: {
    description: kubernetesAlertRuleGroupDescription
    scopes: [
      amw.id
      mc.id
    ]
    clusterName: mc.name
    interval: 'PT1M'
    rules: [
      {
        alert: 'KubeContainerOOMKilledCount'
        expression: 'sum by (cluster,container,controller,namespace)(kube_pod_container_status_last_terminated_reason{reason="OOMKilled"} * on(cluster,namespace,pod) group_left(controller) label_replace(kube_pod_owner, "controller", "$1", "owner_name", "(.*)")) > 0'
        for: 'PT5M'
        annotations: {
          description: 'Number of OOM killed containers is greater than 0. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts).'
        }
        enabled: true
        severity: 4
        resolveConfiguration: {
          autoResolved: true
          timeToResolve: 'PT10M'
        }
        labels: {
          severity: 'warning'
        }
        actions: []
      }
    ]
  }
}

resource sqrPodFailed 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = {
  name: 'PodFailedScheduledQuery'
  location: location
  properties: {
    autoMitigate: true
    displayName: '[${clusterName}] Scheduled Query for Pod Failed Alert'
    description: 'Alert on pod Failed phase.'
    severity: 3
    enabled: true
    scopes: [
      logAnalyticsWorkspaceResourceId
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT10M'
    criteria: {
      allOf: [
        {
          query: '//https://learn.microsoft.com/azure/azure-monitor/containers/container-insights-log-alerts \r\n let endDateTime = now(); let startDateTime = ago(1h); let trendBinSize = 1m; let clusterName = "${clusterName}"; KubePodInventory | where TimeGenerated < endDateTime | where TimeGenerated >= startDateTime | where ClusterName == clusterName | distinct ClusterName, TimeGenerated | summarize ClusterSnapshotCount = count() by bin(TimeGenerated, trendBinSize), ClusterName | join hint.strategy=broadcast ( KubePodInventory | where TimeGenerated < endDateTime | where TimeGenerated >= startDateTime | distinct ClusterName, Computer, PodUid, TimeGenerated, PodStatus | summarize TotalCount = count(), PendingCount = sumif(1, PodStatus =~ "Pending"), RunningCount = sumif(1, PodStatus =~ "Running"), SucceededCount = sumif(1, PodStatus =~ "Succeeded"), FailedCount = sumif(1, PodStatus =~ "Failed") by ClusterName, bin(TimeGenerated, trendBinSize) ) on ClusterName, TimeGenerated | extend UnknownCount = TotalCount - PendingCount - RunningCount - SucceededCount - FailedCount | project TimeGenerated, TotalCount = todouble(TotalCount) / ClusterSnapshotCount, PendingCount = todouble(PendingCount) / ClusterSnapshotCount, RunningCount = todouble(RunningCount) / ClusterSnapshotCount, SucceededCount = todouble(SucceededCount) / ClusterSnapshotCount, FailedCount = todouble(FailedCount) / ClusterSnapshotCount, UnknownCount = todouble(UnknownCount) / ClusterSnapshotCount| summarize AggregatedValue = avg(FailedCount) by bin(TimeGenerated, trendBinSize)'
          metricMeasureColumn: 'AggregatedValue'
          operator: 'GreaterThan'
          threshold: 3
          timeAggregation: 'Average'
          failingPeriods: {
            minFailingPeriodsToAlert: 2
            numberOfEvaluationPeriods: 2
          }
        }
      ]
    }
  }
}
