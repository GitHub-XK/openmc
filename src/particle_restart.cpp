#include "openmc/particle_restart.h"

#include "openmc/constants.h"
#include "openmc/hdf5_interface.h"
#include "openmc/mgxs_interface.h"
#include "openmc/nuclide.h"
#include "openmc/output.h"
#include "openmc/particle.h"
#include "openmc/photon.h"
#include "openmc/random_lcg.h"
#include "openmc/settings.h"
#include "openmc/simulation.h"
#include "openmc/tallies/tally.h"

#include <algorithm> // for copy
#include <array>
#include <string>

namespace openmc {

void read_particle_restart(Particle& p, int& previous_run_mode)
{
  // Write meessage
  write_message("Loading particle restart file " +
    settings::path_particle_restart + "...", 5);

  // Open file
  hid_t file_id = file_open(settings::path_particle_restart, 'r');

  // Read data from file
  read_dataset(file_id, "current_batch", simulation::current_batch);
  read_dataset(file_id, "generations_per_batch", settings::gen_per_batch);
  read_dataset(file_id, "current_generation", simulation::current_gen);
  read_dataset(file_id, "n_particles", settings::n_particles);
  std::string mode;
  read_dataset(file_id, "run_mode", mode);
  if (mode == "eigenvalue") {
    previous_run_mode = RUN_MODE_EIGENVALUE;
  } else if (mode == "fixed source") {
    previous_run_mode = RUN_MODE_FIXEDSOURCE;
  }
  read_dataset(file_id, "id", p.id_);
  int type;
  read_dataset(file_id, "type", type);
  p.type_ = static_cast<Particle::Type>(type);
  read_dataset(file_id, "weight", p.wgt_);
  read_dataset(file_id, "energy", p.E_);
  read_dataset(file_id, "xyz", p.r());
  read_dataset(file_id, "uvw", p.u());

  // Set energy group and average energy in multi-group mode
  if (!settings::run_CE) {
    p.g_ = p.E_;
    p.E_ = data::energy_bin_avg[p.g_ - 1];
  }

  // Set particle last attributes
  p.wgt_last_ = p.wgt_;
  p.r_last_current_ = p.r();
  p.r_last_ = p.r();
  p.u_last_ = p.u();
  p.E_last_ = p.E_;
  p.g_last_ = p.g_;

  // Close hdf5 file
  file_close(file_id);
}

void run_particle_restart()
{
  // Set verbosity high
  settings::verbosity = 10;

  // Create cross section caches
  #pragma omp parallel
  {
    simulation::micro_xs = new NuclideMicroXS[data::nuclides.size()];
    simulation::micro_photon_xs = new ElementMicroXS[data::elements.size()];
  }

  // Initialize the particle to be tracked
  Particle p;

  // Read in the restart information
  int previous_run_mode;
  read_particle_restart(p, previous_run_mode);

  // Set all tallies to 0 for now (just tracking errors)
  model::tallies.clear();

  // Compute random number seed
  int64_t particle_seed;
  switch (previous_run_mode) {
  case RUN_MODE_EIGENVALUE:
    particle_seed = (simulation::total_gen + overall_generation() - 1)*settings::n_particles + p.id_;
    break;
  case RUN_MODE_FIXEDSOURCE:
    particle_seed = p.id_;
    break;
  }
  set_particle_seed(particle_seed);

  // Transport neutron
  p.transport();

  // Write output if particle made it
  print_particle(&p);

  // Clear cross section caches
  #pragma omp parallel
  {
    delete[] simulation::micro_xs;
    delete[] simulation::micro_photon_xs;
  }
}

} // namespace openmc
