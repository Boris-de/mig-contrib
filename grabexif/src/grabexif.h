/* defs */
#ifndef TRUE
#define TRUE 1
#endif
#ifndef FALSE
#define FALSE 0
#endif

/* Structure Declarations */
typedef struct grabexif_list {
  char *filename;
  int file_size;
  char *resolution;
  char *shutter_speed;
  char *aperture_stop;
  char *quality;
  char *flash_mode;
  struct tm *date;
} ImageData;

/* Function Declarations */
void grabexif_help( void );
int grabexif_process_input( char *filename , char *output_filename );
int grabexif_process_output( ImageData *info , char *output_filename );
void grabexif_check_null( char *assignee, int errnum );
void grabexif_error( int errnum );

/* Global Variables */
const char version[] = { "0.1 Blake Matheny <bmatheny@purdue.edu> 09/01/02" };
char *programname;
int debug;

/* Macros */
#define GRABEXIF_DEFAULT_OUTPUT_FILE "exif.inf"
#define GRABEXIF_DEFAULT_INPUT_FILE "DATA.HTM"
#define GRABEXIF_FORM \
"File name    : %s\n"\
"File size    : %d bytes\n"\
"File date    : %d:%02d:%02d %02d:%02d:%02d\n"\
"Camera make  : Casio\n"\
"Camera model : Casio QV-7000SX\n"\
"Date/Time    : %d:%02d:%02d %02d:%02d:00\n"\
"Resolution   : %s\n"\
"Flash used   : %s\n"\
"Focal length : Unknown\n"\
"CCD width    : Unknown\n"\
"Exposure time: %s\n"\
"Aperture     : %s\n"\
"Focus dist.  : Unknown\n"\
"Metering Mode: Unknown\n"\
"Jpeg Quality : %s\n"\
"Jpeg process : Unknown\n\n"
