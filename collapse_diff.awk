#!/usr/bin/awk -f

function assert(condition, message) {
  if (condition)
    return
  print message > "/dev/stderr"
  exit (g_error = 1)
}

BEGIN {
  MAX_GROUP_SIZE = (ARGC > 1) ? ARGV[1] : 4
  CONTEXT_SIZE = (ARGC > 2) ? ARGV[2] : 2
  assert(CONTEXT_SIZE * 2 <= MAX_GROUP_SIZE, "Context is too large")
  g_group_size = 0
  ARGC = 1
}

function on_group_begin(line) {
  assert(!g_group_type, "Already in group")
  line_begin = substr(line, 1, 1)
  g_group_type = line_begin
  add_line_to_group(line)
}

function add_line_to_group(line) {
  assert(g_group_type, "Not in group")
  if (g_group_size < MAX_GROUP_SIZE) {
    g_group[g_group_size] = line
  }
  g_end_context[g_group_size % CONTEXT_SIZE] = line
  ++g_group_size
}

function on_group_end(print_from_begin_) {
  assert(g_group_type, "Not in group")
  print_from_begin_ = (g_group_size <= MAX_GROUP_SIZE) ? g_group_size :
                                                         CONTEXT_SIZE
  for (i = 0; i < print_from_begin_; ++i) {
    print g_group[i]
  }
  if (g_group_size > MAX_GROUP_SIZE) {
    printf "%s <<<<< skipped %d lines >>>>>\n",
        g_group_type, (g_group_size - 2 * CONTEXT_SIZE)
    for (i = 0; i < CONTEXT_SIZE; ++i) {
      print g_end_context[(g_group_size + i) % CONTEXT_SIZE]
    }
  }
  g_group_type = ""
  g_group_size = 0
}

{
  line_begin = substr($0, 1, 1)
  if (!g_group_type) {
    if (line_begin == "+" || line_begin == "-") {
      on_group_begin($0)
    } else {
      print
    }
  } else if (line_begin == g_group_type) {
    add_line_to_group($0)
  } else {
    on_group_end()
    print
  }
}

END {
  if (g_group_type)
    on_group_end()
  if (g_error)
    exit g_error
}
