local com = import 'lib/commodore.libjsonnet';
local esp = import 'lib/espejote.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local utils = import 'utils.libsonnet';

// The hiera parameters for the component
local inv = kap.inventory();
local params = inv.parameters.namespaces;
local instanceName = inv.parameters._instance;

local espNamespace = inv.parameters.espejote.namespace;
local mrName = '%s-label-sync' % instanceName;
local rbacName = 'managedresource-%s-label-sync' % instanceName;

// RBAC for Espejote
local espejoteRBAC = [
  {
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: {
      labels: {
        'app.kubernetes.io/component': 'rbac',
        'app.kubernetes.io/name': mrName,
      },
      name: mrName,
      namespace: espNamespace,
    },
  },
  {
    apiVersion: 'v1',
    kind: 'ClusterRole',
    metadata: {
      labels: {
        'app.kubernetes.io/component': 'rbac',
        'app.kubernetes.io/name': rbacName,
      },
      name: rbacName,
    },
    rules: [
      {
        apiGroups: [ '' ],
        resources: [ 'namespaces' ],
        verbs: [ 'get', 'list', 'watch', 'patch' ],
      },
    ],
  },
  {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRoleBinding',
    metadata: {
      labels: {
        'app.kubernetes.io/component': 'rbac',
        'app.kubernetes.io/name': rbacName,
      },
      name: rbacName,
    },
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'ClusterRole',
      name: rbacName,
    },
    subjects: [
      {
        kind: 'ServiceAccount',
        name: mrName,
        namespace: espNamespace,
      },
    ],
  },
];

// Espejote resources

local managedResource = esp.managedResource(mrName, espNamespace) {
  metadata+: {
    annotations: {
      'syn.tools/description': |||
        Manages labels of namespaces based on namespace prefixes.
        See https://hub.syn.tools/namespaces/index.html for details.
      |||,
    },
  },
  spec: {
    context: [
      {
        name: 'namespaces',
        resource: {
          apiVersion: 'v1',
          kind: 'Namespace',
        },
      },
    ],
    triggers: [
      {
        name: 'namespace',
        watchContextResource: {
          name: 'namespaces',
        },
      },
    ],
    serviceAccountRef: {
      name: espejoteRBAC[0].metadata.name,
    },
    template: ('local config = %s;\n' % std.manifestJson(params.labelSync)) + (importstr 'espejote-templates/label-sync.jsonnet'),
  },
};

// Check if espejote is installed and resources are configured
local hasEspejote = std.member(inv.applications, 'espejote');
local hasDynamicLabels = std.length(params.labelSync.applyOnPrefix) > 0;

// Define outputs below
if hasDynamicLabels && hasEspejote then
  {
    '00_espejote_rbac': espejoteRBAC,
    '00_espejote_mr': managedResource,
  }
else if hasDynamicLabels then
  std.trace(
    'espejote must be installed',
    {}
  )
else {}
