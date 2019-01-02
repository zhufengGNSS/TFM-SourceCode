#!/usr/bin/perl -w

# Package declaration:
package DataDumper;


# TODO: SCRIPT DESCRIPTION GOES HERE:

# Import modules:
# ---------------------------------------------------------------------------- #
use Carp;         # enables advanced warning and failure raise...
use strict;       # enables strict syntax and common mistakes advisory...
use Data::Dumper; # enables nested struct pretty print...

use feature      qq(say);               # same as print.$text.'\n'...
use feature      qq(switch);            # switch functionality...
use Scalar::Util qq(looks_like_number); # scalar utility...

# Import configuration and common interfaces module:
use lib qq(/home/ppinto/TFM/src/); # TODO: set enviroment variable!
use GeneralConfiguration qq(:ALL);

# Import dedicated libraries:
use lib qq(/home/ppinto/TFM/src/lib/); # TODO: this should be an enviroment!
# Common tools:
use MyUtil   qq(:ALL); # useful subs and constants...
use MyPrint  qq(:ALL); # print and warning/failure utilities...
# GNSS dedicated tools:
use Geodetic qq(:ALL); # geodetic toolbox...
use TimeGNSS qq(:ALL); # GNSS time transforming utilities...

# Import dependent modules:
use RinexReader qq(:ALL);
use ErrorSource qq(:ALL);
use SatPosition qq(:ALL);
use RecPosition qq(:ALL);

# Set package exportation properties:
# ---------------------------------------------------------------------------- #
BEGIN {
  # Load export module:
  require Exporter;

  # Set package version:
  our $VERSION = 1.0;

  # Inherit from Exporter to export subs and constants:
  our @ISA = qq(Exporter);

  # Default export:
  our @EXPORT = ();

  # Define constants to export:
  our @EXPORT_CONST = qw(  );

  # Define subroutines to export:
  our @EXPORT_SUB   = qw( &DumpLSQInfo
                          &DumpSatObsData
                          &DumpSatPosition
                          &DumpRecPosition
                          &DumpRecSatLoSData );

  # Merge constants and subroutines:
  our @EXPORT_OK = (@EXPORT_CONST, @EXPORT_SUB);

  # Define export tags:
  our %EXPORT_TAGS = ( ALL         => \@EXPORT_OK,
                       DEFAULT     => \@EXPORT,
                       CONSTANTS   => \@EXPORT_CONST,
                       SUBROUTINES => \@EXPORT_SUB );
}


# ---------------------------------------------------------------------------- #
# Constants:
# ---------------------------------------------------------------------------- #
use constant {
  WARN_NO_SELECTED_OBS => 90101,
};

# ---------------------------------------------------------------------------- #
# Subroutines:
# ---------------------------------------------------------------------------- #

# Public Subroutines: #
# ............................................................................ #
sub DumpSatObsData {
  my ( $ref_dump_conf, $ref_gen_conf, $ref_obs_data,
       $ref_sats_to_ignore, $ref_selected_obs, $output_path, $fh_log ) = @_;

  # Default input values if not defined:
  $fh_log = *STDOUT unless $fh_log;

  # ************************* #
  # Input consistency cehcks: #
  # ************************* #

  # Output path must exist and have write permissions:
  unless (-w $output_path) {
    RaiseError($fh_log, ERR_WRITE_PERMISSION_DENIED,
      "User '".$ENV{USER}."' does not have write permissions at $output_path");
    return KILLED;
  }

  # Dumper configuration must be hash type:
  unless (ref($ref_dump_conf) eq 'HASH') {
    RaiseError($fh_log, ERR_WRONG_HASH_REF,
      "Input argument \'$ref_dump_conf\' is not HASH type");
    return KILLED;
  }

  # General configuration must be hash type:
  unless (ref($ref_gen_conf) eq 'HASH') {
    RaiseError($fh_log, ERR_WRONG_HASH_REF,
      "Input argument \'$ref_gen_conf\' is not HASH type");
    return KILLED;
  }

  # Observation data must be hash type:
  unless (ref($ref_obs_data) eq 'HASH') {
    RaiseError($fh_log, ERR_WRONG_HASH_REF,
      "Input argument \'$ref_obs_data\' is not HASH type");
    return KILLED;
  }

  # Satellites to discard must be array type:
  unless (ref($ref_sats_to_ignore) eq 'ARRAY') {
    RaiseError($fh_log, ERR_WRONG_ARRAY_REF,
      "Input argument \'$ref_sats_to_ignore\' is not ARRAY type");
    return KILLED;
  }

  # Selected observations must be array type:
  unless (ref($ref_selected_obs) eq 'ARRAY') {
    RaiseError($fh_log, ERR_WRONG_ARRAY_REF,
      "Input argument \'$ref_selected_obs\' is not ARRAY type");
    return KILLED;
  }

  # ***************************************** #
  # Satellite Observations data dump routine: #
  # ***************************************** #

  # De-reference array inputs:
  my @selected_obs   = @{ $ref_selected_obs   };
  my @sats_to_ignore = @{ $ref_sats_to_ignore };

  # Save dumper useful configuration:
  my $separator     = $ref_dump_conf->{ SEPARATOR    };
  my $ref_epoch_sub = $ref_dump_conf->{ EPOCH_FORMAT };

  # Dump the data for each selected GNSS constellation:
  for my $sat_sys (@{$ref_gen_conf->{SELECTED_SAT_SYS}})
  {
    # 1. Open dumper file at output path:
      my $file_path = join('/', ($output_path, "$sat_sys-sat_obs_data.out"));
      my $fh; open($fh, '>', $file_path) or croak "Could not create $!";

    # 2. Write title line:
      say $fh sprintf("# > RINEX satellite observation data. Created : %s \n".
                      "# > Observation epoch status info:\n".
                      "#   0   --> OK\n".
                      "#   1-6 --> NOK\n",
                      GetPrettyLocalDate());

    # 3. Write header:
      # Check for constellation available observations:
      my @sat_sys_obs;
      my @avail_obs = @{ $ref_obs_data->{HEAD}{SYS_OBS_TYPES}{$sat_sys}{OBS} };

      # Filter available observations by the selected ones:
      for my $obs (sort @avail_obs) {
        if (grep(/^$obs$/, @selected_obs)) { push(@sat_sys_obs, $obs); }
      }

      # Raise Warning if no observations are left:
      unless( @sat_sys_obs ) {
        RaiseWarning($fh_log, WARN_NO_SELECTED_OBS,
          "No observations for constellation '$sat_sys' have been selected.\n".
          "Please, reconsider the following configuration: \n".
          "  - Available observations : ".join(', ', @avail_obs)."\n".
          "  - Selected  observations : ".join(', ', @selected_obs));
      }

      # Header line items:
      my @header_items = qw(Epoch Status Sat_PRN);
      push(@header_items, "$_") for (@sat_sys_obs);

      # Write header:
      say $fh "# ".join($separator, @header_items);

    # 4. Dump satellite observations:
      for (my $i = 0; $i < scalar(@{$ref_obs_data->{BODY}}); $i += 1)
      {
        # Save epoch data reference:
        my $ref_epoch_data = $ref_obs_data->{BODY}[$i];

        # Save observation epoch status:
        my $status = $ref_epoch_data->{STATUS};

        # Epoch is transformed according to data dumper configuration:
        my @epoch =
          &{$ref_dump_conf->{EPOCH_FORMAT}}( $ref_epoch_data->{EPOCH} );

        # Write observations for each observed satellite:
        for my $sat (sort ( keys %{$ref_epoch_data->{SAT_OBS}} ))
        {
          unless (grep(/^$sat$/, @sats_to_ignore)) {
            # Save raw observations:
            my @obs;
            push(@obs, $ref_epoch_data->{SAT_OBS}{$sat}{$_}) for (@sat_sys_obs);
            # Dump observation data:
            say $fh join($separator, (@epoch, $status, $sat, @obs));
          }
        } # end for my $sat
      } # end for $i

    # 5. Close dumper file:
      close($fh);

  } # end for $sat_sys

  # If successfull, the sub returns boolean TRUE answer:
  return TRUE;
}

sub DumpRecSatLoSData {
  my ($ref_dump_conf, $ref_gen_conf, $ref_obs_data,
      $ref_sats_to_ignore, ) = @_;


}

sub DumpLSQInfo {}

sub DumpSatPosition {}

sub DumpRecPosition {}


TRUE;
