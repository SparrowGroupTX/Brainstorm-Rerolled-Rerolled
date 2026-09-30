# Detached correction after spent M17 adapter parse error

M17 returned error before its host-generated Lua chunk could execute. The new preload emitter placed a Lua long-string literal directly against the indexing bracket: `package.preload[` plus `[[name]]` produced ambiguous adjacent brackets. The established emitter includes spaces around that key. This one-line correction copies exactly that spacing into the three new module preloads.

The frozen M17 files, registration, spent receipt, trace and error remain unchanged. Its audit records no source-Lua initialization, UI callback, observed-result injection, product launch, advisor action or native search. The error does not establish any product startup behavior.

`generated_preload_syntax.lua` compiles the exact old and new emitter outputs using the three frozen product modules. It requires each old output to fail compilation and each corrected output to compile. Four synthetic contents stress closing long-string delimiters. None of the generated modules executes. This closes the test gap left by M17's Python AST and standalone-Lua parsing, which never parsed the generated outer snippets.

The `adapter/` copy changes only that emitter. It is preparation for a possible future component, without registration or authority to run it. Its copied worker still expects the spent M17 registration and must not be run. Parent decides whether a distinct fresh lease is justified, then updates the future worker identity/provenance before registration. All earlier full-Game-update, UI display, input, logger, cache and other qualification limits remain.
