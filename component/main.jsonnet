// main template for namespaces
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();

// The hiera parameters for the component
local params = inv.parameters.namespaces;
local instanceName = inv.parameters._instance;
local instanceKey = std.strReplace(instanceName, '-', '_');
local instanceParams = inv.parameters[instanceKey];

// List of namespace names that are allowed to be configured
local isOpenshift = std.member([ 'openshift4', 'oke' ], inv.parameters.facts.distribution);
local ignoreList = params.ignoreList + (if isOpenshift then [ 'openshift' ] else []);
local isReserved(name) = std.any([
  std.startsWith(name, prefix)
  for prefix in ignoreList
]);

// Prevent configuring namespaces in `parameters.namespaces`
assert std.length(std.setDiff(std.objectFields(params.namespaces), std.objectFields(instanceParams.namespaces))) == 0 : "configuring namespaces in `parameters.namespaces.namespaces` isn't allowed";

local namespace(name) = {
  assert !isReserved(name) : 'namespace "%s" is not allowed' % name,

  apiVersion: 'v1',
  kind: 'Namespace',
  metadata: {
    annotations: {
      'argocd.argoproj.io/sync-options': 'Delete=false',
    },
    labels: {
      name: name,
    },
    name: name,
  } + com.makeMergeable(instanceParams.namespaces[name]),
};

// Define outputs below
{
  [name]: namespace(name)
  for name in std.objectFields(instanceParams.namespaces)
}
