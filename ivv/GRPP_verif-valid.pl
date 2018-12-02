#!/usr/bin/perl -w

## SCRIPT DESCRIPTION GOES HERE ##

# ============================================================================ #

# Perl modules:
# ---------------------------------------------------------------------------- #
use Carp;            # enhanced user warning and error messages...
use strict;          # enables strict syntax...
use Data::Dumper;    # hash pretty print...
use feature qq(say); # print method adding carriage jump...

use Memory::Usage;
use Time::HiRes qw(gettimeofday tv_interval);

# Common modules:
# ---------------------------------------------------------------------------- #
use lib qq(/home/ppinto/TFM/src/lib/);
use MyUtil  qq(:ALL);
use MyPrint qq(:ALL);

# Configuration and common interface module:
# ---------------------------------------------------------------------------- #
use lib qq(/home/ppinto/TFM/src/);
use GeneralConfiguration qq(:ALL);

# GRPP tool packages:
# ---------------------------------------------------------------------------- #
use lib qq(/home/ppinto/TFM/src/GNSS_RINEX_Post-Processing/);
use RinexReader qq(:ALL);
# use ErrorSource qq(:ALL);
use SatPosition qq(:ALL);
# use RecPosition qq(:ALL);

# ============================================================================ #

PrintTitle1( *STDOUT, "Script $0 has started" );

# Prelimary:
  # Init script clock:
  my $script_start = [gettimeofday];

  # Init memory usage report:
  our $MEM_USAGE = Memory::Usage->new();
      $MEM_USAGE->record('Script start. All modules have been loaded!');

# ---------------------------------------------------------------------------- #

# Script inputs:
#   $1 --> path to configuration file
  my $path_conf_file = $ARGV[0];

# Load general configuration:
  my $ref_gen_conf = LoadConfiguration($path_conf_file);

  if ($ref_gen_conf == KILLED) {
    croak "*** ERROR *** Failed when reading configuration file: $path_conf_file"
  }

# Open output log file:
  our $FH_LOG; open($FH_LOG, '>', $ref_gen_conf->{LOG_FILE_PATH}) or croak $!;

  PrintTitle1($FH_LOG, "GRPP Verification-Validation Script");

# ---------------------------------------------------------------------------- #

# RINEX reading:
  PrintTitle2($FH_LOG, "Reading RINEX observation data");
  my $ref_obs_rinex = ReadObservationRinexV3( $ref_gen_conf,
                                              $FH_LOG );

  # print Dumper $ref_obs_rinex;

# Compute satellite positions:
  PrintTitle2($FH_LOG, "Reading RINEX navigation data");
  my $ref_gps_nav_rinex = ComputeSatPosition( $ref_gen_conf,
                                              $ref_obs_rinex,
                                              $FH_LOG );

# Close output log file:
  close($FH_LOG);


# Terminal:
  # Report memory usage:
  PrintTitle2(*STDOUT, 'Memory Usage report:');
  $mem_usage->dump();

  # Stop script clock and report elapsed time:
  my $script_stop  = [gettimeofday];
  my $elapsed_time = tv_interval($script_start, $script_stop);

  say ""; PrintTitle3( *STDOUT, sprintf("Elapsed script time : %.2f seconds",
                                        $elapsed_time) ); say "";

PrintTitle1( *STDOUT, "Script $0 has finished" );
