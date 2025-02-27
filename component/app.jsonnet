local argocd = import 'lib/argocd.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local instance = inv.parameters._instance;

// Prevent creating a non-instantiated instance
assert instance != 'namespaces' : 'component must be instantiated with a name';

local app = argocd.App(instance, 'default') {
  spec+: {
    syncPolicy+: {
      syncOptions+: [
        'ServerSideApply=true',
      ],
    },
  },
};

local appPath =
  local project = std.get(std.get(app, 'spec', {}), 'project', 'syn');
  if project == 'syn' then 'apps' else 'apps-%s' % project;

{
  ['%s/%s' % [ appPath, instance ]]: app,
}
