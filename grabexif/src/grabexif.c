/* grabexif
   Copyright (C) 2002 dbaseiv.net

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software Foundation,
   Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA */

/* grabexif.c 
 * Author: Blake Matheny <bmatheny@purdue.edu>
 * 
 * Generate exif.inf files for mig (mig.sf.net) use, from html files found
 * on Casio QV-7000SX (and others?).
 */

#include <stdio.h>
#include <errno.h>
#include <unistd.h>
#include <stdlib.h>
#include <ctype.h>
#include <string.h>
#include <fcntl.h>
#include <time.h>
#include <regex.h>
#include <sys/types.h>
#include <sys/stat.h>
#include "grabexif.h"

int main ( int argc, char **argv )
{
  int c;
  char *input_file, *output_file;
  debug = 0;

  input_file = output_file = NULL;

  if ( argv[0] )
    programname = argv[0];
  else
    programname = "unknown";

  while ( (c = getopt(argc, argv, "dhi:o:")) != -1 ) {
    switch ( c ) {
      case 'd':
	debug = 1;
	break;
      case 'h':
	grabexif_help();
	break;
      case 'i':
	input_file = strdup(optarg);
	grabexif_check_null(input_file, ENOMEM);
	break;
      case 'o':
	output_file = strdup(optarg);
        grabexif_check_null(output_file,ENOMEM);
	break;
      default:
	grabexif_help();
	break;
    }
  }

  if ( input_file == NULL ) {
    input_file = strdup(GRABEXIF_DEFAULT_INPUT_FILE);
    grabexif_check_null(input_file, ENOMEM);
  }

  if ( output_file == NULL ) {
    output_file = strdup(GRABEXIF_DEFAULT_OUTPUT_FILE);
    grabexif_check_null(input_file, ENOMEM);
  }

  if ( grabexif_process_input(input_file, output_file) < 0 )
    grabexif_error(errno);

  fprintf(stdout,
	  "%s - Success!\n", programname);
  exit(0);
}

int grabexif_process_input( char *filename , char *output_filename )
{
  FILE *fname;
  char *buf, *temp;
  ImageData *info;
  int flag, i, counter, ampm;
  flag = FALSE;
  counter = 1;
  i = ampm = 0;
  fname = NULL;
  buf = temp = NULL;

  fname = fopen(filename, "r");

  if ( fname == NULL ) {
    perror("fopen");
    return -1;
  }

  buf = malloc(4096);
  grabexif_check_null(buf, ENOMEM);
  memset(buf, 0, 4096);

  info = (ImageData*)malloc(sizeof(ImageData));
  grabexif_check_null((char*)info, ENOMEM);

  while ( fgets(buf, 4096, fname) != NULL ) {
    if ( (temp = strstr(buf, "<B>")) != NULL ) {
      info->filename = (char*)malloc(strlen(temp)*sizeof(char));
      grabexif_check_null(info->filename, ENOMEM);
      memset(info->filename, 0, (strlen(temp)*sizeof(char)));
      sscanf(temp, "<B>%s", info->filename);
      for ( i = 0 ; i < strlen(info->filename); i++ ) {
	if ( (flag == TRUE) ||
	     ((info->filename[i] == 60) && (info->filename[i+1] == 47))) {
	  flag = TRUE;
	  info->filename[i] = 0;
	}
      }  
      flag = FALSE;
      if ( debug ) { fprintf(stdout, "Filename: %s\n", info->filename); }
    } else if ( (temp = strstr(buf, "<PRE> : ")) != NULL ) {
      sscanf(temp, "%*s : %d%*s", &info->file_size);
      if(debug)
	fprintf(stdout, "File Size: %d\n", info->file_size);
    } else if ( (temp = strstr(buf, " : ")) != NULL ) {
      /* if i % 13 == 0 do something */
      if ( ((counter-1) % 13) == 0 ) { /* We found the resolution */
	info->resolution = (char*)malloc(sizeof(char)*strlen(temp));
	grabexif_check_null(info->resolution, ENOMEM);
	memset(info->resolution, 0, strlen(temp));
	sscanf(temp," %*s %s", info->resolution);
	if ( debug )
	  fprintf(stdout, "Resolution: %s\n", info->resolution);
      } else if ( ((counter-2) % 13) == 0 ) { /* Found Quality */
	info->quality = (char*)malloc(sizeof(char)*strlen(temp));
	grabexif_check_null(info->quality, ENOMEM);
	memset(info->quality, 0, strlen(temp));
	sscanf(temp, " %*s %s", info->quality);
	if ( debug )
	  fprintf(stdout, "Quality: %s\n", info->quality);
      } else if ( ((counter-6) % 13) == 0 ){ /* Found shutter_speed */
	info->shutter_speed = (char*)malloc(sizeof(char)*strlen(temp));
	grabexif_check_null(info->shutter_speed, ENOMEM);
	memset(info->shutter_speed, 0, strlen(temp));
	sscanf(temp, " %*s %s", info->shutter_speed);
	if ( debug )
	  fprintf(stdout, "Shutter Speed: %s\n", info->shutter_speed);
      } else if ( ((counter-7) % 13) == 0 ) { /* Found aperture_stop */
	info->aperture_stop = (char*)malloc(sizeof(char)*strlen(temp));
	grabexif_check_null(info->aperture_stop, ENOMEM);
	memset(info->aperture_stop, 0, strlen(temp));
	sscanf(temp, " %*s %s", info->aperture_stop);
	if ( debug )
	  fprintf(stdout, "Aperture Stop: %s\n", info->aperture_stop);
      } else if ( ((counter-10) %13 ) == 0 ) { /* Found Flash */
	info->flash_mode = (char*)malloc(sizeof(char)*strlen(temp));
	grabexif_check_null(info->flash_mode, ENOMEM);
	memset(info->flash_mode, 0, strlen(temp));
	sscanf(temp, " %*s %s", info->flash_mode);
	if ( debug )
	  fprintf(stdout, "Flash Mode: %s\n", info->flash_mode);
      } else if ( ((counter-13) % 13) == 0 ) { /* Found date */
	info->date = (struct tm*)malloc(sizeof(struct tm));
	sscanf(temp, " : %d/%d/%d %d:%d", &info->date->tm_year,
	       &info->date->tm_mon, &info->date->tm_mday, &info->date->tm_hour,
	       &info->date->tm_min);
	if ( tolower(temp[strlen(temp)-4]) == 112 ){ /* checking for p in pm */
	  ampm = info->date->tm_hour+12;
	  info->date->tm_hour = ampm;
	}
	if ( debug ) {
	  fprintf(stdout, "Date: %d/%02d/%02d %02d:%02d\n",info->date->tm_year,
		  info->date->tm_mon, info->date->tm_mday, info->date->tm_hour,
		  info->date->tm_min);
	  fprintf(stdout, "------------------------------\n");
	}
	if ( grabexif_process_output(info, output_filename) < 0 )
	  return -1;
      }
      counter++;
    }
  }

  return 0;
}

int grabexif_process_output( ImageData *info, char *output_filename )
{
  int fd, size;
  char *constring;
  struct stat buf;
  struct tm *timep;
  time_t tloc;

  fd = open(output_filename, O_CREAT|O_APPEND|O_WRONLY,
	    S_IRUSR|S_IWUSR|S_IRGRP|S_IROTH);
  if ( fd < 0 ) {
    perror("open");
    return -1;
  }

  size = (
    strlen(info->filename)+strlen(info->resolution)+strlen(info->shutter_speed)
    +strlen(info->aperture_stop)+strlen(GRABEXIF_FORM)+strlen(info->quality)+
    50);
  constring = (char*)malloc(sizeof(char)*size);
  grabexif_check_null(constring, ENOMEM);

  if ( stat(info->filename, &buf) < 0 ) {
    tloc = time(NULL);
    timep = localtime(&tloc);
  } else
    timep = localtime(&buf.st_mtime);

  snprintf(constring, size, GRABEXIF_FORM, info->filename, info->file_size,
	   timep->tm_year+1900, timep->tm_mon+1, timep->tm_mday,
	   timep->tm_hour, timep->tm_min, timep->tm_sec, info->date->tm_year,
	   info->date->tm_mon, info->date->tm_mday, info->date->tm_hour,
	   info->date->tm_min, info->resolution, info->flash_mode,
	   info->shutter_speed, info->aperture_stop, info->quality);

  write(fd, constring, strlen(constring));
  close(fd);
  return 0;
}
void grabexif_check_null( char *assignee, int errnum )
{
  if ( assignee == NULL )
    grabexif_error(errnum);
}

void grabexif_error( int errnum )
{
  switch ( errnum ) {
    case ENOMEM:
      fprintf(stdout,
	      "%s - Out of memory, exiting.\n", programname);
      exit(1);
      break;
    default:
      fprintf(stdout,
	      "%s - Error, exiting. Run with '-h' switch for help\n",
	      programname);
      exit(1);
      break;
  }
}

void grabexif_help( void )
{
  fprintf(stderr,
	  "%s - %s\n", programname, version);
  fprintf(stderr,
	  "Usage: %s [options]\n", programname);
  fprintf(stderr,
	  "Options:\n");
  fprintf(stderr,
	  "  -d\t\t\tDebug Output\n");
  fprintf(stderr,
	  "  -h\t\t\tHelp\n");
  fprintf(stderr,
	  "  -i <file>\t\tInput File\n");
  fprintf(stderr,
	  "  -o <file>\t\tOutput File\n");
}

