Fix repeated journal/public-observer callback wrapping that accumulated during
idle updates and multiplied action observations. Both modules now share recorded
ancestry for product-owned wrappers, preserving replacement callbacks and the
full existing journal information.

The player's compact windows confirm severe frame stalls, but their measured
journal work is too small to establish that direct logging is the sole cause.
Wrapper accumulation is reproduced in manufactured tests; allocation/GC impact
and restored live frame rate remain unmeasured. Activation requires the user's
normal restart. All logs, settings, native DLLs and closed experiment outcomes
remain preserved. Root's exact-installed record supplies final validation counts.
