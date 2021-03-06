#!/usr/bin/perl -w

## TODO: SCRIPT DESCRIPTION GOES HERE ##

# ============================================================================ #

# Load bash enviroments:
# ---------------------------------------------------------------------------- #
use lib $ENV{ ENV_ROOT };
use Enviroments qq(:CONSTANTS);

# Perl modules:
# ---------------------------------------------------------------------------- #
use Carp;            # enhanced user warning and error messages...
use strict;          # enables strict syntax...
use Storable;        # save raw hashes
use Data::Dumper;    # hash pretty print...
use feature qq(say); # print method adding carriage jump...

use Memory::Usage;
use Time::HiRes qw(gettimeofday tv_interval);

# Common modules:
# ---------------------------------------------------------------------------- #
use lib LIB_ROOT_PATH;
use MyUtil   qq(:ALL);
use MyMath   qq(:ALL);
use MyPrint  qq(:ALL);
use Geodetic qq(:ALL);
use TimeGNSS qq(:ALL);

# Configuration and common interfaces module:
# ---------------------------------------------------------------------------- #
use lib SRC_ROOT_PATH;
use GeneralConfiguration qq(:ALL);

# GRPP tool packages:
# ---------------------------------------------------------------------------- #
use lib GRPP_ROOT_PATH;
use RinexReader qq(:ALL);
use SatPosition qq(:ALL);
use RecPosition qq(:ALL);
use DataDumper  qq(:ALL);

# ============================================================================ #

PrintTitle1( *STDOUT, "Script $0 has started" );

# Prelimary:
  # Init script clock:
  my $script_start = [gettimeofday];

  # Init memory usage report:
  our $MEM_USAGE = Memory::Usage->new();
      $MEM_USAGE->record('-> Imports');

# ---------------------------------------------------------------------------- #

# Script inputs:
#   $1 --> path to configuration file
  my $path_conf_file = $ARGV[0];

# Load general configuration:
  my $ref_gen_conf = LoadConfiguration($path_conf_file);

  # print Dumper $ref_gen_conf; exit 0;

  if ($ref_gen_conf == KILLED) {
    croak "*** ERROR *** Failed when reading configuration file: $path_conf_file"
  }

# Open output log file:
  our $FH_LOG; open($FH_LOG, '>', $ref_gen_conf->{LOG_FILE_PATH}) or croak $!;

  PrintTitle1($FH_LOG, "GRPP Verification-Validation Script");

# ---------------------------------------------------------------------------- #

# RINEX reading:
  my $ini_rinex_obs_time_stamp = [gettimeofday];

  PrintTitle2($FH_LOG, "Reading RINEX observation data");
  my $ref_obs_data = ReadObservationRinexV3( $ref_gen_conf,
                                              $FH_LOG );

  ReportElapsedTime([gettimeofday],
                    $ini_rinex_obs_time_stamp, "ReadObservationRinex()");
  $MEM_USAGE->record('-> ReadObsRinex');


# Compute satellite positions:
  my $ini_rinex_nav_time_stamp = [gettimeofday];

  PrintTitle2($FH_LOG, "Reading RINEX navigation data");
  my $ref_gps_nav_rinex = ComputeSatPosition( $ref_gen_conf,
                                              $ref_obs_data,
                                              $FH_LOG );

  # print Dumper $ref_obs_data->{BODY}[0]; exit 0;


  ReportElapsedTime([gettimeofday],
                    $ini_rinex_nav_time_stamp, "ComputeSatPosition()");
  $MEM_USAGE->record('-> ComputeSatPosition');

# Compute Receiver positions:
  my $ini_rec_position_time_stamp = [gettimeofday];

  PrintTitle2($FH_LOG, "Computing Receiver positions");
  my $rec_position_status = ComputeRecPosition( $ref_gen_conf,
                                                $ref_obs_data,
                                                $ref_gps_nav_rinex,
                                                $FH_LOG );

  # print Dumper $ref_obs_data->{BODY}[0]{NUM_SAT_INFO}{ALL}; exit 0;
  # print Dumper $ref_obs_data->{BODY}[0]{LSQ_INFO}; exit 0;

  ReportElapsedTime([gettimeofday],
                    $ini_rec_position_time_stamp, "ComputeRecPosition()");
  $MEM_USAGE->record('-> ComputeRecPosition');

  # Print position solutions for validating GRPP functionality:
  PrintTitle3(*STDOUT, "Position solutions. ",
                       "first 4 and last 4 observation epochs:");
  for (0..3, -4..-1) {
    PrintComment( *STDOUT, "Observation epoch : ".
      BuildDateString(GPS2Date($ref_obs_data->{BODY}[$_]{EPOCH})).
      "| Status = ".
      ($ref_obs_data->{BODY}[$_]{REC_POSITION}{STATUS} ? "OK":"NOK") );
    PrintBulletedInfo(*STDOUT, "  ",
      "|  X |  Y |  Z =".
        join(' | ',
          sprintf( " %12.3f |" x 3,
                   @{$ref_obs_data->
                      {BODY}[$_]{REC_POSITION}{XYZ}} )
        ),
      "| sX | sY | sZ =".
        join(' | ',
          sprintf(" %12.3f |" x 3,
                  map{$_**0.5} @{$ref_obs_data->
                                  {BODY}[$_]{REC_POSITION}{VAR_XYZ}})
        )
      );

    say "[...]\n" if ($_ == 3);
  }

# # Read precise orbit file:
#     my $ini_precise_orbit_time_stamp = [gettimeofday];
#
#     PrintTitle2($FH_LOG, "Reading Precise Orbit information:");
#
#     my $ref_precise_orbit =
#       ReadPreciseOrbitIGS( $ref_gen_conf->{IGS_PRECISE}{ORBIT_PATH}, $FH_LOG );
#
#     ReportElapsedTime([gettimeofday],
#                       $ini_precise_orbit_time_stamp, "ReadPreciseOrbitIGS()");
#     $MEM_USAGE->record('-> ReadPreciseOrbitIGS');


# Dump processed data:
  PrintTitle2($FH_LOG, "Dumping GRPP data:");
  my $ini_time_dump_data = [gettimeofday];

  PrintTitle3($FH_LOG, "Dumping Satellite Observation Data:");
  DumpSatObsData( $ref_gen_conf,
                  $ref_obs_data,
                  [
                   $ref_gen_conf->{SELECTED_SIGNALS}{E},
                   $ref_gen_conf->{SELECTED_SIGNALS}{G}
                  ],
                  $ref_gen_conf->{OUTPUT_PATH}, $FH_LOG );

  ReportElapsedTime([gettimeofday],
                    $ini_time_dump_data, "DumpSatObsData()");
  $MEM_USAGE->record('-> DumpObsData');

  $ini_time_dump_data = [gettimeofday];

  PrintTitle3($FH_LOG, "Dumping Satellite-Receiver LoS Data:");
  DumpRecSatLoSData( $ref_gen_conf,
                     $ref_obs_data,
                     $ref_gen_conf->{OUTPUT_PATH}, $FH_LOG );

  ReportElapsedTime([gettimeofday],
                    $ini_time_dump_data, "DumpRecSatLoSData()");
  $MEM_USAGE->record('-> DumpRecSatLoSData');

  $ini_time_dump_data = [gettimeofday];

  PrintTitle3($FH_LOG, "Dumping Leas Squares report:");
  DumpLSQReportByIter( $ref_gen_conf,
                       $ref_obs_data,
                       $ref_gen_conf->{OUTPUT_PATH}, $FH_LOG );

  ReportElapsedTime([gettimeofday],
                    $ini_time_dump_data, "DumpLSQReportByIter()");
  $MEM_USAGE->record('-> DumpLSQReportByIter');

  DumpLSQReportByEpoch( $ref_gen_conf,
                        $ref_obs_data,
                        $ref_gen_conf->{OUTPUT_PATH}, $FH_LOG );

  ReportElapsedTime([gettimeofday],
                    $ini_time_dump_data, "DumpLSQReportByEpoch()");
  $MEM_USAGE->record('-> DumpLSQReportByEpoch');

  $ini_time_dump_data = [gettimeofday];

  PrintTitle3($FH_LOG, "Dumping Satellite XYZ & clock bias:");
  DumpSatPosition( $ref_gen_conf,
                   $ref_obs_data,
                   $ref_gen_conf->{OUTPUT_PATH}, $FH_LOG );

  ReportElapsedTime([gettimeofday],
                    $ini_time_dump_data, "DumpSatPosition()");
  $MEM_USAGE->record('-> DumpSatPosition');

  $ini_time_dump_data = [gettimeofday];

  PrintTitle3($FH_LOG, "Dumping Receiver position & clock bias:");
  DumpRecPosition( $ref_gen_conf,
                   $ref_obs_data,
                   $ref_gen_conf->{OUTPUT_PATH}, $FH_LOG );

  ReportElapsedTime([gettimeofday],
                    $ini_time_dump_data, "DumpRecPosition()");
  $MEM_USAGE->record('-> DumpRecPosition');

  PrintTitle3($FH_LOG, "Dumping Number of satellites information:");
  DumpNumValidSat( $ref_gen_conf,
                   $ref_obs_data,
                   $ref_gen_conf->{OUTPUT_PATH}, $FH_LOG );

  ReportElapsedTime([gettimeofday],
                    $ini_time_dump_data, "DumpNumValidSat()");
  $MEM_USAGE->record('-> DumpNumValidSat');

  PrintTitle3($FH_LOG, "Dumping DOP information:");
  DumpEpochDOP( $ref_gen_conf,
                $ref_obs_data,
                $ref_gen_conf->{OUTPUT_PATH}, $FH_LOG );

  ReportElapsedTime([gettimeofday],
                    $ini_time_dump_data, "DumpEpochDOP()");
  $MEM_USAGE->record('-> DumpEpochDOP');

  PrintTitle3($FH_LOG, "Dumping Elevation by Satellite:");
  DumpElevationBySat( $ref_gen_conf,
                      $ref_obs_data,
                      $ref_gen_conf->{OUTPUT_PATH}, $FH_LOG );

  ReportElapsedTime([gettimeofday],
                    $ini_time_dump_data, "DumpElevationBySat()");
  $MEM_USAGE->record('-> DumpElevationBySat');

  PrintTitle3($FH_LOG, "Dumping Azimut by Satellite:");
  DumpAzimutBySat( $ref_gen_conf,
                   $ref_obs_data,
                   $ref_gen_conf->{OUTPUT_PATH}, $FH_LOG );

  ReportElapsedTime([gettimeofday],
                    $ini_time_dump_data, "DumpAzimutBySat()");
  $MEM_USAGE->record('-> DumpAzimutBySat');

  PrintTitle3($FH_LOG, "Dumping Ionosphere delay by Satellite:");
  DumpIonoCorrBySat( $ref_gen_conf,
                     $ref_obs_data,
                     $ref_gen_conf->{OUTPUT_PATH}, $FH_LOG );

  ReportElapsedTime([gettimeofday],
                    $ini_time_dump_data, "DumpIonoCorrBySat()");
  $MEM_USAGE->record('-> DumpIonoCorrBySat');

  PrintTitle3($FH_LOG, "Dumping Troposphere delay by Satellite:");
  DumpTropoCorrBySat( $ref_gen_conf,
                      $ref_obs_data,
                      $ref_gen_conf->{OUTPUT_PATH}, $FH_LOG );

  ReportElapsedTime([gettimeofday],
                    $ini_time_dump_data, "DumpTropoCorrBySat()");
  $MEM_USAGE->record('-> DumpTropoCorrBySat');

  PrintTitle3($FH_LOG, "Dumping Residuals by Satellite:");
  DumpResidualsBySat( $ref_gen_conf,
                      $ref_obs_data,
                      $ref_gen_conf->{OUTPUT_PATH}, $FH_LOG );

  ReportElapsedTime([gettimeofday],
                    $ini_time_dump_data, "DumpResidualsBySat()");
  $MEM_USAGE->record('-> DumpResidualsBySat');

  # PrintTitle3($FH_LOG, "Dumping precise orbit information:");
  # DumpPreciseSatellitePosition( $ref_gen_conf,
  #                               $ref_obs_data,
  #                               $ref_precise_orbit,
  #                               $ref_gen_conf->{OUTPUT_PATH}, $FH_LOG );

  ReportElapsedTime([gettimeofday],
                    $ini_time_dump_data, "DumpPreciseSatellitePosition()");
  $MEM_USAGE->record('-> DumpPreciseSatellitePosition');

# Save raw data hash:
  store($ref_gen_conf, $ref_gen_conf->{OUTPUT_PATH}."/ref_gen_conf.hash");
  store($ref_obs_data, $ref_gen_conf->{OUTPUT_PATH}."/ref_obs_data.hash");

# Terminal:
  # Close output log file:
    close($FH_LOG);

  # Report memory usage:
  PrintTitle2(*STDOUT, 'Memory Usage report:');
  $MEM_USAGE->dump();

  # Stop script clock and report elapsed time:
  my $script_stop  = [gettimeofday];
  my $elapsed_time = tv_interval($script_start, $script_stop);

  say ""; PrintTitle2( *STDOUT, sprintf("Elapsed script time : %.2f seconds",
                                        $elapsed_time) ); say "";

PrintTitle1( *STDOUT, "Script $0 has finished" );


sub ReportElapsedTime {
  my ($current_time_stamp, $ref_time_stamp, $label) = @_;

  say "";
    PrintTitle2( *STDOUT, sprintf("Elapsed time for $label %.2f seconds",
                          tv_interval($ref_time_stamp, $current_time_stamp)) );
  say "";
}
