// One arm, one module graph.
//
// The ESM loader keys its cache on the whole specifier, so importing
// `status.js?page=2` gives that arm its own entry module -- and, without this
// hook, the same shared `./chat.js` every earlier arm already mutated. The
// resolve hook carries the `page` query from a parent onto every relative
// specifier it imports, so one query on the entry point gives the whole graph
// its own instances and its own state objects.

export async function resolve(specifier, context, nextResolve) {
  const resolved = await nextResolve(specifier, context);
  const parent = context.parentURL || '';
  const page = /[?&]page=([^&#]+)/.exec(parent);
  if (!page || !/^\.{1,2}\//.test(specifier) || /[?&]page=/.test(resolved.url)) {
    return resolved;
  }
  const separator = resolved.url.includes('?') ? '&' : '?';
  return { ...resolved, url: `${resolved.url}${separator}page=${page[1]}`, shortCircuit: true };
}
