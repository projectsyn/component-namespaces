local esp = import 'espejote.libsonnet';
local context = esp.context();

local ignoreNamespace(namespace) =
  if std.member(config.ignoreNames, namespace.metadata.name) then
    true
  else if std.length(std.filter(
    function(prefix) std.startsWith(namespace.metadata.name, prefix),
    config.ignorePrefixes
  )) > 0 then
    true
  else false;

// Get the labels from a namespace name prefix by
// first finding the prefixes that match with the namespace name
// then return the labels defined for that prefix.
local labelsFromPrefix(namespace) =
  local prefixes = std.filter(
    function(prefix) std.startsWith(namespace.metadata.name, prefix),
    std.objectFields(config.applyOnPrefix)
  );

  if std.length(prefixes) > 0 then prefixLabels[prefixes[0]] else {};

// Reconcile the given namespace.
local reconcileNamespace(namespace) =
  // Check if the namespace can be ignored
  if ignoreNamespace(namespace) then []
  // Apply labels if the namespace name contains 'carema'
  else if labelsFromContains(namespace) != {} then [
    namespace {
      metadata+: {
        labels+: labelsFromContains(namespace),
      },
    },
  ]
  // Apply labels if the namespace name starts with defined prefix
  else if labelsFromPrefix(namespace) != {} then [
    namespace {
      metadata+: {
        labels+: labelsFromPrefix(namespace),
      },
    },
  ]
  else [];

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
    reconcileNamespace(nsTrigger.resource)
) else (
  // Reconcile all namespaces for managedresource reconcile.
  local namespaces = context.namespaces;
  std.flattenArrays([
    reconcileNamespace(ns)
    for ns in namespaces
    if !inDelete(ns)
  ])
)
