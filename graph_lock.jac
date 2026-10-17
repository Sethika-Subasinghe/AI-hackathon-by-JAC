"""One lock for operations that add nodes to the shared graph or run a whole case.

The server answers requests in parallel, and a long request (`run_case_by_id`) writes
back its view of the graph when it ends, which can erase a node another request added
meanwhile (a case or clinic patient created during the run just disappears). Taking this
lock around those operations makes them queue up instead. Reads and polling never take it.
"""

import threading;

glob GRAPH_LOCK = threading.RLock();
