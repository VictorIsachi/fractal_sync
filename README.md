# Fractal Sync
Fractal Synchroniser: HW synchronisation module design to scale better than mesh-based or monolithic approaches

### Simulation
**1** - Download and update *Bender*:
```bash
make bender
```
**2** - *Generate* compilation script:
```bash
make compile_script
```
**3** - *Start* simulation:
```bash
make start_sim
```

Compilation script and `work/` folder can be removed with:
```bash
make clear
```

### Note
Proper error injection simulation and mitigation strategies should be explored. Currently errors are not managed by the synchronization network and stalls/deadlocks are possible if not properly programmed.
