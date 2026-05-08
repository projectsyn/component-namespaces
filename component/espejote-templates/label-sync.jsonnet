local esp = import 'espejote.libsonnet';
local context = esp.context();

// check if the object is getting deleted by checking if it has
// `metadata.deletionTimestamp`.
local inDelete(obj) = std.get(obj.metadata, 'deletionTimestamp', '') != '';

// Do the thing
if esp.triggerName() == 'namespace' then (
  // Handle single namespace update on namespace trigger
  local nsTrigger = esp.triggerData();
  // nsTrigger.resource can be null if we're called when the namespace is getting
  // deleted. If it's not null, we still don't want to do anything when the
  // namespace is getting deleted.
  if nsTrigger.resource != null && !inDelete(nsTrigger.resource) then
    functions.reconcileNamespace(nsTrigger.resource, config)
) else (
  // Reconcile all namespaces for managedresource reconcile.
  local namespaces = context.namespaces;
  std.flattenArrays([
    functions.reconcileNamespace(ns, config)
    for ns in namespaces
    if !inDelete(ns)
  ])
)
