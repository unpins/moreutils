/* Cosmopolitan portability shims for the Windows (cosmo) multicall build.
 *
 * waitid(): cosmo libc has only the raw sys_waitid stub, no portable
 * waitid() — the same gap parallel.c already papers over for __CYGWIN__
 * with a waitpid()-based emulation. parallel is the sole caller and only
 * ever uses waitid(P_ALL, 0, &infop, WEXITED [| WNOHANG]), reading just
 * si_pid/si_code/si_status, so this covers exactly that. WEXITED is
 * masked off before waitpid(): it's waitid-domain; waitpid()'s implied
 * behaviour already is "wait for exited children".
 */
#ifndef MU_COSMO_COMPAT_H
#define MU_COSMO_COMPAT_H
#include <sys/types.h>
#include <sys/wait.h>
#include <signal.h>
#include <errno.h>

typedef enum { P_ALL, P_PID, P_PGID } mu_idtype_t;

static int mu_waitid(mu_idtype_t idtype, id_t id, siginfo_t *infop, int options) {
	pid_t pid;
	int status;
	switch (idtype) {
		case P_PID:  pid = id;  break;
		case P_PGID: pid = -id; break;
		case P_ALL:  pid = -1;  break;
		default: errno = EINVAL; return -1;
	}
	pid = waitpid(pid, &status, options & WNOHANG);
	if (pid == -1)
		return -1;
	infop->si_pid = pid;
	infop->si_signo = SIGCHLD;
	if (pid == 0)
		return 0;
	if (WIFEXITED(status)) {
		infop->si_code = CLD_EXITED;
		infop->si_status = WEXITSTATUS(status);
	} else if (WIFSIGNALED(status)) {
		infop->si_code = CLD_KILLED;
		infop->si_status = WTERMSIG(status);
	} else if (WIFSTOPPED(status)) {
		infop->si_code = CLD_STOPPED;
		infop->si_status = WSTOPSIG(status);
	}
	return 0;
}
#define waitid mu_waitid
#endif
