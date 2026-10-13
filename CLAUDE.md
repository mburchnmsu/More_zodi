# More_zodi — SPHEREx zodiacal-light emulator

Neural-network emulator (Julia/Flux) of the Kelsall (1998) 5 μm zodiacal-light model (via ZodiPy) for SPHEREx.
Mentored research project; validate on simulated data before real SPHEREx data.

- Setup cell for every notebook: `zodi_setup.jl`, then helpers in `sweeps/*.jl`.
- Records: dated notebooks at the root (`MMDDYYYY.ipynb`), `sweeps/REPORT*.md`, `figures/`.
- Packaged model: `emulator/`. Real-data pipeline: `pipeline/` (star masking is off until the user says otherwise).
- Read the latest notebook and reports before proposing new experiments.

## Syncing between PCs (GitHub: mburchnmsu/More_zodi, private)

The user works on two PCs. Keep the repo in sync without being asked:
- Start of a session: `git pull --ff-only` (a hook may already have done it).
- End of a session, or when the user signs off: commit the session's changes with a clear message and `git push`.
- If a pull or push conflicts, stop and tell the user. Don't force-push or resolve it silently.
- Never commit `sweeps/results/` (GBs of saved runs) or `data/*.h5`. They stay on the machine that made them;
  copy the h5 inputs by hand to a new machine.

Keep this project separate from the exoplanet-vetting project: different repos, different sessions.

## Notify the user on major progress

The user steers sessions from their phone and wants a push notification (PushNotification tool) when something big
happens, even if they didn't ask in that session. Major means: a sweep or long run finishes or crashes, a new best model
or a result that changes the plan, a notebook finished for the mentor, or a blocker that needs their decision.
Not routine steps. One line, lead with the result, e.g. "Round 9 done: parallax bands fix ecliptic stripe, 4x worse elsewhere".