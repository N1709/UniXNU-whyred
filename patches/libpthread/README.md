# libpthread patches

`build-libpthread-kernel.py` applies every `*.patch` in this directory to the
pinned libpthread checkout, sorted by file name, and skips a patch whose
reverse already applies.

The device directory exists because module patch resolution is first-wins:
when a device repository carries `patches/libpthread/`, it shadows UniXNU's
directory instead of adding to it. Both patches therefore live here.

- `explicit-kernel-address.patch` is UniXNU's patch carried byte for byte
  (`sha256 e07db8de...`). It replaces the `NULL` initialisers and arguments
  with `0` in `kern/kern_support.c` and `kern/kern_synch.c`, because
  `user_addr_t` is an integer here and clang rejects the pointer conversion.
- `xnu-8796-no-jit-entitlement.patch`
  (`sha256 b558e5af...`) stops
  `_bsdthread_register` advertising `PTHREAD_FEATURE_JIT_ENTITLED`, whose
  `proc_get_jit_entitled` callback xnu-8796 does not have. The pinned drop is
  the iOS 17 libpthread and is one API ahead of this kernel in exactly that
  place; the other 59 callbacks resolve against 8796. Without it the component
  does not compile, which is the `1 error generated` that run `42922819047`
  reported before its log was truncated.

The order matters only in that both must apply to revision
`c0e60fb5ecfc54cf379c261d3f9572cc22ded891`; neither changes the context of the
other. Reproduce with:

```
git clone --shared ../UniXNU/out/feeds/libpthread-9e5201bd /tmp/lp
git -C /tmp/lp apply patches/libpthread/explicit-kernel-address.patch
git -C /tmp/lp apply patches/libpthread/xnu-8796-no-jit-entitlement.patch
```
