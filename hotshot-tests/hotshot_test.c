#include <stdio.h>

#if defined(_MSC_VER)
#define NOINLINE __declspec(noinline)
#else
#define NOINLINE __attribute__((noinline))
#endif

#if defined(__clang__)
#define ANNO(text) __attribute__((annotate(text)))
#else
#define ANNO(text)
#endif

#if defined(ENABLE_HOTSHOT_MARKER)
#define HOTSHOT_MARKER() asm("hotshot")
#else
#define HOTSHOT_MARKER() ((void)0)
#endif

static const char kMessage[] = "hotshot-message";
static volatile int g_sink = 0;

NOINLINE static int helper_add(int a, int b) { return a + b; }
NOINLINE static int helper_mul(int a, int b) { return a * b; }

NOINLINE ANNO("indirectcall") static int test_indirect_call(int x) {
  return helper_add(x, 7) + helper_mul(x, 2);
}

NOINLINE ANNO("indirectbr") static int test_indirect_branch(int x) {
  if ((x & 1) != 0) {
    return x + 11;
  }
  return x - 9;
}

NOINLINE ANNO("flatten,boguscfg,substitution,aliasaccess,linearmba") static int
test_ir_mix(int x) {
  int local = x ^ 0x5A;
  int value = (local & 0x3F) | 0x10;

  if ((value & 1) != 0) {
    value += helper_add(x, 1);
  } else {
    value -= helper_add(x, 2);
  }

  for (int i = 0; i < 3; ++i) {
    value = (value ^ (i + 3)) + (value & 7);
  }

  g_sink = value;
  return value;
}

NOINLINE ANNO("customcc") static int test_custom_cc(int x) { return x * 5 - 3; }

NOINLINE ANNO("mergefunction") static int test_merge_one(int x) { return x + 100; }
NOINLINE ANNO("mergefunction") static int test_merge_two(int x) { return x - 7; }

NOINLINE ANNO("flatten,boguscfg,substitution") static int test_backend(int x) {
  int value = x + 9;
  HOTSHOT_MARKER();

  if ((value & 1) != 0) {
    value ^= 0x21;
  } else {
    value += 6;
  }

  return value;
}

int main(void) {
  int total = 0;

  total += test_indirect_call(5);
  total += test_indirect_branch(7);
  total += test_ir_mix(9);
  total += test_custom_cc(8);
  total += test_merge_one(10);
  total += test_merge_two(10);
  total += test_backend(12);

  printf("%s:%d\n", kMessage, total);
  return total == 291 ? 0 : 1;
}
