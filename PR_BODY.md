## Problem

Integration scenarios could leave processes running after they finished:

- On timeout the runner sent `TERM` only to `@wait_thr.pid`. The scenario command runs through `sh -c`, so that pid is the shell: the ruby process and anything it forked (swarm nodes, CLI subprocesses) were orphaned and kept running.
- A scenario that exited while something it forked was still running left that process behind, with nothing to notice or clean it up.

Locally this piled up orphaned `karafka ... (supervising)`/`(running)`/`(stopping)` processes that ran for hours.

## Change

- Every scenario runs in its own process group (`Open3.popen3(cmd, pgroup: true)`). Nothing in Karafka changes the session or process group, so everything a scenario starts stays in it.
- Once the scenario process exits, every process still running in its group is killed and listed in the output (`Killed processes left running by <spec>:`). Zombies are skipped.
- On the CI (`CI` set), a scenario that left processes behind fails, so leaking specs get fixed instead of being cleaned up silently. Locally they are only killed and reported.
- A timed out scenario gets `TERM` for the whole group, and `KILL` 30 seconds later if it is still around.
- The header documents running a single spec through the runner (`bin/integrations path/to/the_spec.rb`) to get the same guarantee, instead of running it directly with ruby.

## Verification

With a throwaway spec forking `sleep(600)` and a clean one:

- without `CI`: the forked process is killed and reported, both scenarios pass;
- with `CI=1`: the forked process is killed and reported, the leaking scenario fails;
- no process is left running in either case.

Specs that leak today will show up as failures in this PR's CI, to be fixed here.
