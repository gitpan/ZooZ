#!perl -w

use strict;
use Data::Dumper qw/Dumper/;
use Getopt::Long;

use lib '/home/aqumsieh/Tk804.025_beta15/lib/site_perl/5.8.3/i686-linux';
use lib '/home/aqumsieh/Perl/myLib';
use Tk 804.025;
use Tk qw/:colors/;
use Tk::NoteBook;
use Tk::Adjuster;
use Tk::ToolBar;
use Tk::Tree;
use Tk::Compound;
use Tk::ItemStyle;
use Tk::Pane;
use Tk::Labelframe;
use Tk::DialogBox;

use ZooZ::Forms;
use ZooZ::Project;
use ZooZ::Options;
use ZooZ::Generic;

use constant DEBUG => 0;

#
# Global vars
#

our (
     $MW,
     $VERSION,

     $SPLASH,
     $SPLASH_MSG,
     $SPLASH_PROG,
     $NO_SPLASH,
     $COPYRIGHT,

     # MainWindow frames
     $FRAME_L,
     $FRAME_M,
     $FRAME_R,

     # toolbar
     $TB,

     # menu
     $MENU,
     $PROJ_MENU,

     # Settings Tab and Hash
     $SETTINGS_F,
     %SETTINGS,
     %DEF_SETTINGS,

     # Widget frame
     $WIDGET_F,

     # Project data
     $PROJID,
     $CURID,
     @PROJECTS, # holds the objects.
     @PAGES,
     @NAMES,

     # icons
     %ICONS,
     $SELECTED_W, # selected widget
     $SELECTED_L, # dummy label

     # Extra ZooZ:: objects
     $FONTOBJ,
     $CALLBACKOBJ,
     $VARREFOBJ,

     # Global hash of all widgets.
     # This can be used by users in callbacks.
     %ZWIDGETS,

     # Options for getOpen/SaveFile
     @FILE_OPTIONS,

     # What files correspond to what projects
     @PROJECT_FILES,
    );


#
# temp vars
#
our %availableWidgets = (
			 butLab   => [qw/Label Image Button Radiobutton Checkbutton/],
			 text     => [qw/Entry Text ROText/],
			 menuList => [qw/Listbox Optionmenu/],
			 datadisp => [qw/Canvas Scale ProgressBar HList NoteBook/],
#			 dialog   => [qw/Dialogbox Toplevel/],
			 misc     => [qw/Labelframe Frame/],
			 parasite => [qw/Scrollbar/],
			);


#
# Inits
#
$VERSION      = '1.0RC2';
$PROJID       = 0;
$NO_SPLASH    = 0;
%DEF_SETTINGS = (
		 -borderwidth => 1,
		);
%SETTINGS     = %DEF_SETTINGS;
@FILE_OPTIONS = (
		 -defaultextension => '.zooz',
		 -initialdir       => '.',
		 -filetypes        =>
		 [
		  ['ZooZ Files', '.zooz'],
		  ['All Files',  '*'    ],
		 ],
		);
$COPYRIGHT     = 'Copyright 2004 - Ala Qumsieh. All rights reserved.';

# Control Data::Dumper
$Data::Dumper::Indent = 0;

#
# Read any command line args
#
GetOptions(
	   nosplash => \$NO_SPLASH,
	  );

#
# create stuff
#

createMW          (); updateSplash('Initializing GUI');
createGUI         (); updateSplash();
createMenu        (); updateSplash();
createToolBar     (); updateSplash('Loading Images');
#defineSettings    ();
loadIcons         (); updateSplash();
loadBitmaps       (); updateSplash('Defining GUI Elements');
defineFonts       (); updateSplash();
defineWidgets     (); updateSplash();
defineStyles      (); updateSplash('Initializing Modules');
createExtraObjects(); updateSplash();
createHandlers    (); updateSplash();
ZooZ::Forms::createAllForms($MW);

$SPLASH->withdraw;
$MW->deiconify;

ZooZ::Generic::popMessage($MW, "Welcome to ZooZv$VERSION");

loadProject($_) for @ARGV;

MainLoop;

sub updateSplash {
  return if $NO_SPLASH;

  $SPLASH_PROG++;
  $SPLASH_MSG = shift if @_;
  $SPLASH->update;
  $MW->after(200);
}

sub createMW {
  $MW = new MainWindow;
  $MW->withdraw;
  $MW->title("ZooZ v$VERSION");
  $MW->geometry("800x600+0+0");
  $MW->protocol(WM_DELETE_WINDOW => \&closeApp);

  { # Create the splash window
    $SPLASH = $MW->Toplevel;
    $SPLASH->withdraw;
    $SPLASH->overrideredirect(1);
    my $f = $SPLASH->Frame(-bd     => 2,
			   -relief => 'ridge',
			  )->pack(qw/-fill both -expand 1/);

    my $logo  = $SPLASH->Photo(-file => 'ZooZ/icons/zooz_logo.gif');
    my $logo2 = $SPLASH->Photo(-file => 'ZooZ/icons/screenshot4logo.gif');

    #$f->Label(-image => $logo)->pack(qw/-side top/);
    $f->Label(-image => $logo2)->pack(qw/-side top/);
    $f->ProgressBar(-from     => 0,
		    -to       => 11,
		    -variable => \$SPLASH_PROG,
		    -width    => 20,
		    -colors   => [0 => 'lightblue'],
		   )->pack(qw/-side top -fill x -pady 10 -padx 10/);

    $f->Label(-textvariable => \$SPLASH_MSG,
	     )->pack(qw/-fill x -side top/);

    $f->Label(-text => $COPYRIGHT,
	      -font => 'Times 10 normal',
	     )->pack(qw/-fill x -side top/);

    $SPLASH_PROG = 0;

    # Now center it.
    $SPLASH->update;
    my $sw = $SPLASH->screenwidth;
    my $sh = $SPLASH->screenheight;
    my $rw = $SPLASH->reqwidth;
    my $rh = $SPLASH->reqheight;

    my $x  = int 0.5 * ($sw - $rw);
    my $y  = int 0.5 * ($sh - $rh);

    $SPLASH->geometry("+$x+$y");
    $SPLASH->deiconify unless $NO_SPLASH;
  }
}

sub createGUI {
  # Left and main frames.
  $FRAME_L = $MW->Frame->pack(qw/-side left -fill y/);
  $FRAME_M = $MW->Frame->pack(qw/-side left -fill both -expand 1/);

  # frame to display selectable widgets.
  $WIDGET_F = $FRAME_L->Labelframe(
				   -text => 'Available Widgets',
				  )->pack(qw/-side top -fill both -expand 1/);

  # Dummy label to drag around.
  $SELECTED_L = $MW->Label(-textvariable => \$SELECTED_W,
			   -bg           => 'cornflowerblue',
			   -relief       => 'raised',
			   -borderwidth  => 1,
			  );

  # pressing Delete deletes selected widget.
  $MW->bind('<Delete>' => sub { $CURID && $PROJECTS[$CURID]->deleteSelectedWidget });
}

sub createMenu {
  $MENU = $MW->Menu(-type => 'menubar', -bd => 1);
  $MW->configure(-menu => $MENU);

  $MENU->optionAdd('*BorderWidth' => 1);

  { # The File menu.
    my $f = $MENU->cascade(-label => '~File', -tearoff => 0);
    for my $ref (
		 ['New Project',   \&newProject],
		 'sep',
		 ['Load Project',  \&loadProject],
		 ['Save Project',  \&saveProject],
		 ['Close Project', \&closeProject],
		 'sep',
		 ['Quit',          \&closeApp],
		) {

      if (ref $ref) {
	$f->command(-label => $ref->[0], -command => $ref->[1]);
      } else {
	$f->separator;
      }
    }
  }

  {
    # The edit menu.
    my $f = $MENU->cascade(-label => '~Edit', -tearoff => 0);
    for my $ref (
		 ['Delete Selected Widget', sub { $CURID && $PROJECTS[$CURID]->deleteSelectedWidget }],
		 'sep',
		 ['Toggle Preview Window',  sub { $CURID && $PROJECTS[$CURID]->togglePreview }],
		 'sep',
		 ['Properties', sub {}],
		) {

      if (ref $ref) {
	$f->command(-label => $ref->[0], -command => $ref->[1]);
      } else {
	$f->separator;
      }
    }
  }

  { # the configure menu.
    my $f = $MENU->cascade(-label => '~Configure', -tearoff => 0);
    for my $ref (
		 ['Configure Selected Widget', sub { $CURID && $PROJECTS[$CURID]->configureSelectedWidget }],
		 'sep',
		 ['Configure Selected Row',    sub { $CURID && $PROJECTS[$CURID]->_configureRowCol('row', 'selected') }],
		 ['Configure Selected Column', sub { $CURID && $PROJECTS[$CURID]->_configureRowCol('col', 'selected') }],
		) {

      if (ref $ref) {
	$f->command(-label => $ref->[0], -command => $ref->[1]);
      } else {
	$f->separator;
      }
    }
  }

  { # The data menu.
    my $f = $MENU->cascade(-label => '~Data', -tearoff => 0);
    for my $ref (
		 ['Variable Definitions', [\&ZooZ::Forms::chooseVar,      '']],
		 ['Callback Definitions', [\&ZooZ::Forms::chooseCallback, '']],
		 ['Font Definitions',     [\&ZooZ::Forms::chooseFont,     '']],
		) {

      if (ref $ref) {
	$f->command(-label => $ref->[0], -command => $ref->[1]);
      } else {
	$f->separator;
      }
    }
  }

  # The project menu
#  $PROJ_MENU = $MENU->cascade(-label   => '~Projects',
#			      -tearoff => 0,
#			     );
  $PROJ_MENU = $MW->Menu(-tearoff     => 0);
  $MENU->add(cascade =>
	     -label  => 'Projects',
	     -underline => 0,
	     -menu   => $PROJ_MENU);

  # What? no help?
}

sub defineSettings {
  # this sub populates the Setting tab.

  my $f = $SETTINGS_F->Scrolled('Pane',
				-sticky     => 'nsew',
				-scrollbars => 'e',
				-gridded    => 'xy',
			       )->pack(qw/-fill both -expand 1/);

  # populate the 'Defaults' frame
  {
    my $defFrame = $f->Labelframe(-text => 'Defaults')->pack(qw/-side top -fill x/);
    $defFrame->optionAdd('*Entry.BorderWidth'  => 1);
    $defFrame->optionAdd('*Button.BorderWidth' => 1);

    my $row = 0;
    my $col = 0;
    for my $ref (
		 [-borderwidth => 'Border Width'],
		 [-background  => 'Background Color'],
		 [-font        => 'Font'],
		 [-foreground  => 'Foreground Color'],
		) {

      ZooZ::Options->addOptionGrid($ref->[0],
				   $ref->[1],
				   $defFrame,
				   $row,
				   $col,
				   \$SETTINGS{$ref->[0]},
				  );

      ($row, $col) = $col ? ($row + 1, 0) : ($row, 4);
    }

    $defFrame->gridColumnconfigure(0, -weight  => 1);
    $defFrame->gridColumnconfigure(4, -weight  => 1);
    $defFrame->gridColumnconfigure(3, -minsize => 20);
  }
}

### TBD. Check for any unsaved projects and prompt.
###      For now, prompt anyway.

sub closeApp {
  # prompt.
  my $ans = $MW->Dialog(-title   => 'Are you sure?',
			-bitmap  => 'question',
			-buttons => [qw/Yes No/],
			-font    => 'Questions',
			-text    => <<EOT)->Show;
If you quit, any unsaved projects
will be lost! Are you sure you want
to quit ZooZ?
EOT
  ;
  return if $ans eq 'No';

  # make sure all localReturns are set.
  ZooZ::Forms::cancelAllForms();

  $MW->destroy;
}

sub defineWidgets {
  my @frames;
  my $firstBut;

  my $dum;

  # make all cells of the same size.
  my $cellwidth  = 0;
  my $cellheight = 0;

  for my $o ([butLab   => 'Labels and Buttons'],
	     [text     => 'Text Related'      ],
	     [menuList => 'Menus and Lists'   ],
	     [datadisp => 'Data Presentation' ],
	     #[dialog   => 'Dialogs'           ],
	     [parasite => 'Non Stand-Alone'   ],
	     [misc     => 'Miscellaneous'     ],
	    ) {

    my $b;

    my $f = $WIDGET_F->Frame(-bg          => 'white',
			     -relief      => 'sunken',
			     -borderwidth => 1);
    $b    = $WIDGET_F->Radiobutton(-text        => $o->[1],
				   -indicatoron => 0,
				   -variable    => \$dum,
				   -value       => $o->[0],
                                   -height      => 2,
                                   -borderwidth => 1,
				   -command     => sub {
				     $_->packForget for @frames;
				     $f->pack(-before => $b, qw/-side top -fill both -expand 1/);
				   })->pack(qw/-fill x -side top/);

    push @frames => $f;

    my $r = my $c = 0;

    for my $w (@{$availableWidgets{$o->[0]}}) {
      my $image  = lc $w;
      my $button = $f->Button(-bg                 => 'white',
			      -relief             => 'flat',
			      -borderwidth        => 1,
			      -highlightthickness => 0,
			      -command            => [\&selectWidgetToAdd, $w],
			       )->grid(-column => $c,
				       -row    => $r,
				       -sticky => 'nsew',
				      );

      my $comp = $button->Compound;
      $button->configure(-image => $comp);
      $comp->Line;
      if (exists $ICONS{$image}) {
	$comp->Image(-image => $ICONS{$image});
      } else {
	$comp->Bitmap(-bitmap => 'error');
      }
      $comp->Line;
      $comp->Text(-text => uc $w, -font => 'WidgetName', -anchor => 's');

      $button->update;
      my $bw = $button->ReqWidth;
      my $bh = $button->ReqHeight;
      $cellwidth  = $bw if $bw > $cellwidth;
      $cellheight = $bh if $bh > $cellheight;

      if ($c) {
	$c = 0;
	$r++;
      } else {
	$c++;
      }
    }

    $firstBut ||= $b;
    $f->gridRowconfigure   (++$r, -weight => 1);
  }

  # make sure they all have the same width.
  $firstBut->invoke;
  $MW->update;
  my $width = (sort {$b <=> $a} map $_->reqwidth, @frames)[0];
  for my $f (@frames) {
    $f->configure(-width => $width);
    $f->gridPropagate(0);
    $f->gridColumnconfigure($_, -minsize => $cellwidth ) for 0, 1;
    $f->gridRowconfigure   ($_, -minsize => $cellheight) for 0 ..($f->gridSize)[1];
  }
}

sub createToolBar {
  # create the ToolBar
  $TB = $MW->ToolBar(qw/-movable 0 -side top -cursorcontrol 0/);
  $TB->Button(-image   => 'filenew16',
	      -tip     => 'New Project',
	      -command => \&newProject,
	     );
  $TB->separator;
  $TB->Button(-image   => 'fileopen16',
	      -tip     => 'Load Project',
	      -command => \&loadProject);
  $TB->Button(-image   => 'filesave16',
	      -tip     => 'Save Project',
	      -command => \&saveProject);
  $TB->Button(-image   => 'fileclose16',
	      -tip     => 'Close Project',
	      -command => \&closeProject,
	     );
  $TB->separator;
  $TB->Button(-image   => 'textsortinc16',
	      -tip     => 'Dump Perl Code',
	      -command => \&dumpPerl,
	     );
  $TB->separator;
  $TB->Button(-image   => 'viewmag16',
	      -tip     => 'Hide/Unhide Preview Window',
	      -command => sub {
		$CURID && $PROJECTS[$CURID]->togglePreview;
	      });
  $TB->Button(-image   => 'apptool16',
	      -tip     => 'Configure Selected Widget',
	      -command => sub {
		$CURID && $PROJECTS[$CURID]->configureSelectedWidget;
	      });
  $TB->Button(-image   => 'actcross16',
	      -tip     => 'Delete Selected Widget',
	      -command => sub {
		$CURID && $PROJECTS[$CURID]->deleteSelectedWidget;
	      });
  $TB->Button(-image   => 'viewmulticolumn16',
	      -tip     => 'Configure Selected Row',
	      -command => sub {
		$CURID && $PROJECTS[$CURID]->_configureRowCol('row', 'selected');
	      });
  $TB->Button(-image   => 'viewicon16',
	      -tip     => 'Configure Selected Column',
	      -command => sub {
		$CURID && $PROJECTS[$CURID]->_configureRowCol('col', 'selected');
	      });
}

sub newProject {
  $PROJECTS[$CURID]->togglePreview('OFF') if $CURID;

  $PROJID++;

  my $name = "Project $PROJID";
  my $page = $FRAME_M->Frame;

  $PAGES   [$PROJID] = $page;
  $NAMES   [$PROJID] = $name;
  $PROJECTS[$PROJID] = new ZooZ::Project
    (
     -id     => $PROJID,
     -top    => $page,
     -name   => $name,
     -title  => $name,
     -icons  => \%ICONS,
    );

  # focus it.
  $CURID = $PROJID;
  $_->packForget for $FRAME_M->packSlaves;
  $page->pack(qw/-fill both -expand 1/);
  $MW->title("ZooZ v$VERSION - $NAMES[$CURID]");

  *ZWIDGETS = $PROJECTS[$CURID]->allWidgetsHash;

  # add it to the menu.
  $PROJ_MENU->command(-label   => $name,
		      -command => [sub {
				     my $id = shift;
				     $PROJECTS[$CURID]->togglePreview('OFF') if $CURID;

				     $CURID = $id;
				     $_->packForget for $FRAME_M->packSlaves;
				     $page->pack(qw/-fill both -expand 1/);
				     $MW->title("ZooZ v$VERSION - $NAMES[$CURID]");
				     $PROJECTS[$CURID]->togglePreview('ON');

				     *ZWIDGETS = $PROJECTS[$CURID]->allWidgetsHash;
				   }, $PROJID]);

  $PROJECT_FILES[$CURID] = "project$CURID.zooz";
}

# must ask to save project first or not.
sub closeProject {
  $CURID or return
    ZooZ::Generic::popMessage
	($MW => "No active project.", 1500);

  my $ans = $MW->Dialog(-title   => 'Are you sure?',
			-bitmap  => 'question',
			-buttons => [qw/Yes No/, 'Save & Close'],
			-font    => 'Questions',
			-text    => <<EOT)->Show;
Any changes you made to the project
will be lost! Are you sure you want
to close $NAMES[$CURID]?
EOT
  ;
  return if $ans eq 'No';

  saveProject() if $ans eq 'Save & Close';

  # close the project. This means:
  # 1. Unmapping it.
  # 2. Cleaning up the project object.
  # 3. Removing it from the Projects menu.
  # 4. Change the MW title.
  #$PAGES   [$CURID]->packForget;
  $PAGES   [$CURID]->destroy;
  $PROJECTS[$CURID]->closeMe;
  $MW->title("ZooZ v$VERSION");

  removeFromMenu($NAMES[$CURID]);
}

sub saveProject {
  $CURID or return
    ZooZ::Generic::popMessage
	($MW => "No active project.", 1500);

  my $f = $MW->getSaveFile(@FILE_OPTIONS,
			   -title => 'Choose File to Save',
			   defined $PROJECT_FILES[$CURID] ?
			   (-initialfile => $PROJECT_FILES[$CURID]) : (),
			  );

  defined $f or return;

  $PROJECT_FILES[$CURID] = $f;

  open my $fh, "> $f" or die $!;

  print $fh "[ZooZ v$VERSION]\n\n";

  $PROJECTS[$CURID]->save($fh);

  # Now dump any subroutines.
  for my $n ($CALLBACKOBJ->listAll) {
    my $code = $CALLBACKOBJ->code($n);
    s/\s+$//, s/^\s+// for $code;

    print $fh <<EOT;
\[Sub $n\]
$code
\[End Sub\]

EOT
  ;
  }

  # And dump any vars.
  for my $v ($VARREFOBJ->listAll) {
    my $val   = $v;
    $val      =~ s/(.)/$ {1}main::/;
    $val      = Dumper($1 eq "\$" ? eval "$val" : eval "\\$val");
    $val      =~ s/\$VAR1 = //;
    $val      =~ s/;$//;
    $val      =~ s/^[\[\{]/\(/;  # stupid cperl mode
    $val      =~ s/[\]\}]$/\)/;

    print $fh <<EOT;
\[Var $v\]
$val
\[End Var\]

EOT
  ;
  }

  close $fh;
}

sub loadProject {
  my $f = shift;

  unless ($f) {
    $f = $MW->getOpenFile(@FILE_OPTIONS,
			  -title => 'Choose File to Load',
			 );
    defined $f or return;
  }

  $MW->Busy;

  open my $fh, $f or die $!;
  newProject();
  my $proj = $PROJECTS[$CURID];
  $PROJECT_FILES[$CURID] = $f;

  my @DATA;
  my @ROWCOLDATA;

  while (<$fh>) {
    s/\#.*//;

    # Is it a widget?
    if (/^\s*\[Widget\s+(\S+)\]/) {
      my %data;
      $data{NAME} = $1;

      # read until the end of the widget definition.
      while (<$fh>) {
	s/\#.*//;
	if (/^\s*\[End\s+Widget\]/) {
	  # create the widget.
	  #$proj->loadWidget(\%data);
	  #last;

	  # Don't create the widgets yet. Do that after the
	  # sub and var definitions have been done.
	  push @DATA => \%data;
	  last;
	}

	if (/^\s*([PWE]CONF)\s+(\S+)(?:\s+(.*))?\s*$/) {
	  my $v = defined $3 ? $3 : '';
	  $data{$1}{$2} = $v eq 'undef' ? undef : $v;
	  next;
	}

	next unless /^\s*(\S+)\s+(\S+)\s*$/;
	$data{$1} = $2;
      }

      # is it a sub definition?
    } elsif (/^\s*\[Sub\s+(\S+)\]/) {
      my $name = $1;
      my $code = '';

      while (<$fh>) {
	last if /^\s*\[End\s+Sub\]/;
	$code .= $_;
      }

      $CALLBACKOBJ->add($name, $code);

      # eval it.
      {
	no strict;
	no warnings;

	$code =~ s/sub \Q$name/sub /;
	*{"main::$name"} = eval "package main; $code";
      }

      $CALLBACKOBJ->name2code($name, eval "\\&main::$name");

      # is it a var?
    } elsif (/^\s*\[Var\s+(\S+)\]/) {
      my $name = $1;
      my $val  = <$fh>;
      <$fh>;  # [End Var]

      $VARREFOBJ->add($name);
      $name =~ s/^(.)/$ {1}main::/;
      eval "$name = $val";

      $VARREFOBJ->name2ref($name, eval "\\$name");

      # Is it a row/col conf option?
    } elsif (/^\s*\[(Row|Col)\s+(\d+)\]/) {
      my $rowOrCol = $1;
      my $num      = $2;

      my %data;
      while (<$fh>) {
	last if /^\s*\[End\s+$rowOrCol\]/;

	$data{$1} = $2 if /^\s*(\S+)\s+(.+?)\s*$/;
      }

      push @ROWCOLDATA => [$rowOrCol, $num, %data];
    }

  }

  # Now create all the widgets.
  $proj->loadWidget($_) for @DATA;
  $proj->unselectCurrentWidget;
  $proj->_unhideCanvas;

  # Load any row/col conf (after widget creation)
  $proj->loadRowCol(@$_) for @ROWCOLDATA;

  $MW->Unbusy;

  ZooZ::Generic::popMessage
      ($MW => "Project file $f loaded successfully.", 1500);
}

sub loadIcons {
  for my $file (<ZooZ/icons/*gif>) {  # should this use Tk->findINC ??
    my ($name) = $file =~ m|.*/(.+)\.gif|;
    $ICONS{$name} = $MW->Photo("$name-zooz", -format => 'gif', -file => $file);
  }
}

sub loadBitmaps {
  my $downbits = pack("b10" x 5,
		      "11......11",
		      ".11....11.",
		      "..11..11..",
		      "...1111...",
		      "....11....",
		     );

  $MW->DefineBitmap('down_size', 10, 5, $downbits);

  my $upbits = pack("b10" x 5,
		    "....11....",
		    "...1111...",
		    "..11..11..",
		    ".11....11.",
		    "11......11",
		   );

  $MW->DefineBitmap('up_size', 10, 5, $upbits);

  # define the h bitmap.
  my $rightbits = pack("b5" x 10,
		       "1....",
		       "11...",
		       ".11..",
		       "..11.",
		       "...11",
		       "...11",
		       "..11.",
		       ".11..",
		       "11...",
		       "1....",
		      );

  $MW->DefineBitmap('right_size', 5, 10, $rightbits);

  my $leftbits = pack("b5" x 10,
		       "....1",
		       "...11",
		       "..11.",
		       ".11..",
		       "11...",
		       "11...",
		       ".11..",
		       "..11.",
		       "...11",
		       "....1",
		      );

  $MW->DefineBitmap('left_size', 5, 10, $leftbits);

  my $rightArrow = pack("b10" x 5,
			"......11..",
			".......11.",
			"1111111111",
			".......11.",
			"......11..",
		       );

  my $leftArrow = pack("b10" x 5,
		       "..11......",
		       ".11.......",
		       "1111111111",
		       ".11.......",
		       "..11......",
		      );

  my $upArrow = pack("b5" x 10,
		     "..1..",
		     ".111.",
		     "11111",
		     "1.1.1",
		     "..1..",
		     "..1..",
		     "..1..",
		     "..1..",
		     "..1..",
		     "..1..",
		    );

  my $downArrow = pack("b5" x 10,
		       "..1..",
		       "..1..",
		       "..1..",
		       "..1..",
		       "..1..",
		       "..1..",
		       "1.1.1",
		       "11111",
		       ".111.",
		       "..1..",
		      );

  my $box = pack("b5" x 5,
		 ".....",
		 ".111.",
		 ".111.",
		 ".111.",
		 ".....",
		);

  $MW->DefineBitmap('rightArrow', 10,  5, $rightArrow);
  $MW->DefineBitmap('leftArrow',  10,  5, $leftArrow );
  $MW->DefineBitmap('upArrow',     5, 10, $upArrow   );
  $MW->DefineBitmap('downArrow',   5, 10, $downArrow );
  $MW->DefineBitmap('box',         5,  5, $box       );
}

sub defineFonts {
  $MW->fontCreate('Row/Col Num',
		  -family => 'Nimbus',
		  -size   => 10,
		  -weight => 'bold',
		 );

  $MW->fontCreate('WidgetName',
		  -family => 'helvetica',
		  -size   => 9,
		 );

  $MW->fontCreate('Questions',
		  -family => 'Nimbus',
		  -size   => 10,
		 );

  $MW->fontCreate('Level',
		  -family => 'helvetica',
		  -size   => 13,
		  -weight => 'normal',
		 );

  $MW->fontCreate('OptionText',
		  -family => 'helvetica',
		  -size   => 11,
		  -weight => 'normal',
		 );

#  $MW->fontCreate('WidgetName',
#		  -family => 'helvetica',
#		  -size   => 12,
#		 );
}

sub selectWidgetToAdd {
  return unless $CURID;

  $SELECTED_W = shift;

  $SELECTED_L->configure(exists $ICONS{lc $SELECTED_W} ?
			 (-image => $ICONS{lc $SELECTED_W}) :
			 (-image => ''));

  my $w = $SELECTED_L->reqwidth  / 2;
  my $h = $SELECTED_L->reqheight / 2;

  my ($x, $y) = $MW->pointerxy;
  $x -= $MW->rootx;
  $y -= $MW->rooty;

  $SELECTED_L->place(-x => $x - $w,
		     -y => $y - $h);

  # set the bindings.

  # when the mouse moves, update the dummy label.
  $MW->bind('<Motion>' => sub {
	      my ($x, $y) = $MW->pointerxy;
	      $x -= $MW->rootx;
	      $y -= $MW->rooty;

	      $SELECTED_L->place(-x => $x - $w,
				 -y => $y - $h);
	    });

  # clicking somewhere does something.
  $MW->bind('<1>' => sub {
	      $CURID or return;

	      $PROJECTS[$CURID]->dropWidgetInCurrentObject
		  or return;

	      endDrag();
	    });

  # pressing escape cancels.
  $MW->bind('<Escape>'    => \&endDrag);
  $MW->bind('<<EndDrag>>' => \&endDrag);
}

sub endDrag {
  $SELECTED_L->placeForget;
  $MW->bind($_ => '') for qw/<Escape> <Motion> <1>/;
}

sub defineStyles {
  $MW->ItemStyle(imagetext         =>
		 -stylename        => 'container',
		 -fg               => 'red',
		 -selectforeground => 'red',
		);
}

sub createExtraObjects {
  # Create the font object
  $FONTOBJ = new ZooZ::Fonts;

  {
    # create the default font.
    # use a dummy label.
    my $l    = $MW->Label      (-text => 'test');
    my $c    = $l  ->configure ('-font');
    my $font = $MW->fontCreate ('Default',
				map {$_ => $c->[-1]->actual($_)}
				qw/-family -size -weight -slant -underline -overstrike/,
			       );
    $l->destroy;
    $FONTOBJ->add(Default => $font);
  }

  # create the callback object
  $CALLBACKOBJ = new ZooZ::Callbacks;

  # create the varRef object
  $VARREFOBJ = new ZooZ::varRefs;
}

sub removeFromMenu {
  my $c = shift;

  for my $i (0 .. $PROJ_MENU->index('last')) {
    my $l = $PROJ_MENU->entrycget($i, '-label');
    next unless $l eq $c;

    $PROJ_MENU->delete($i);
    last;
  }
}

sub createHandlers {
  $SIG{__DIE__} = sub {
    # ignore the error due to CodeText if it's not present.
    return if $_[0] =~ m{Can't locate Tk/CodeText\.pm};

    my $msg = "\n\nMessage:\n$_[0]";
    chomp $msg;

    my $ans = $MW->Dialog(-title   => 'Fatal Error Detected',
			  -bitmap  => 'error',
			  -buttons => [qw/Ok Quit/],
			  -font    => 'Questions',
			  -text    => join ' ' => split " \n", <<EOT)->Show;
A fatal error has been detected and was trapped! 
You can press 'Ok' and continue, but it is best 
that you save your work and restart. If you can 
reproduce this behaviour, then please send the necessary 
steps to do so to aqumsieh\@cpan.org.
$msg
EOT
  ;

    CORE::exit if $ans eq 'Quit';

    $MW->deiconify;
    goto &MainLoop;
  };

  open my $warnLog, "> ZooZ.log" or
    die "ERROR: Could not create log file: $!\n";

  $SIG{__WARN__} = sub {
    print $warnLog shift;
  };

  $SIG{INT} = \&closeApp;
}

sub dumpPerl {
  $CURID or return
    ZooZ::Generic::popMessage
	($MW => "No active project.", 1500);

  $MW->Busy;

  my $fileName = $PROJECT_FILES[$CURID];
  $fileName =~ s/\.[^.]+$/\.pl/; # chang extension

  my $f = $MW->getSaveFile(
			   -title       => 'Choose File to Save',
			   -initialfile => $fileName,
			  );

  $f or return;

  open my $fh, "> $f" or die "$f: $!\n";

  # some headers.
  my $time = localtime;

  print $fh <<EOT;
#!perl

##################
#
# This file was automatically generated by ZooZ.pl v$VERSION
# on $time.
# Project: $NAMES[$CURID]
# File:    $PROJECT_FILES[$CURID]
#
##################

#
# Headers
#
use strict;
use warnings;
use lib '/home/aqumsieh/Tk804.025_beta15/lib/site_perl/5.8.3/i686-linux';
use Tk 804;

#
# Global variables
#
my (
     # MainWindow
     \$MW,

     # Hash of all widgets
     \%ZWIDGETS,
    );

#
# User-defined variables (if any)
#
EOT
  ;

  # now dump the user-defined vars.
  local $Data::Dumper::Indent = 2;

  for my $v ($VARREFOBJ->listAll) {
    my $val   = $v;
    $val      =~ s/(.)/$ {1}main::/;
    $val      = Dumper($1 eq "\$" ? eval "$val" : eval "\\$val");
    $val      =~ s/\$VAR1 = //;
    $val      =~ s/;$//;
    $val      =~ s/^[\[\{]/\(/;  # stupid cperl mode
    $val      =~ s/[\]\}]$/\)/;

    chomp $val;

    print $fh <<EOT;
my $v = $val;

EOT
  ;
  }

  # Create the MainWindow
  print $fh <<'EOT';

######################
#
# Create the MainWindow
#
######################

$MW = MainWindow->new;

######################
#
# Load any images
#
######################
ZloadImages();
EOT
  ;

  # Now let the project do it's thing.
  $PROJECTS[$CURID]->dumpPerl($fh);

  # finish off
  print $fh <<EOT;


###############
#
# MainLoop
#
###############

MainLoop;

#######################
#
# Subroutines
#
#######################

EOT
  ;

  # Now the subroutines.

  # first subroutine is ZloadImages();
  my $images = $PROJECTS[$CURID]->getImageHash;

  print $fh "sub ZloadImages {\n";
  for my $file (keys %$images) {
    my $name = $images->{$file};

    my $method;
    if    ($file =~ /\.(?:gif|ppm|pgm)$/) { $method = 'Photo'  }
    elsif ($file =~ /\.bmp$/)             { $method = 'Bitmap' }
    elsif ($file =~ /\.xpm$/)             { $method = 'Pixmap' }
    else {
      # should never be here.
      next;
    }

    print $fh "  \$MW->$method('$name', -file => '$file');\n";
  }
  print $fh "}\n\n";

  # and the user-defined subs.
  for my $n ($CALLBACKOBJ->listAll) {
    my $code = $CALLBACKOBJ->code($n);
    s/\s+$//, s/^\s+// for $code;
    $code =~ s/\A\#.*\n//;
    $code =~ s/sub main::/sub /;

    print $fh <<EOT;
$code

EOT
  ;
  }
  close $fh;

  $MW->Unbusy;

  ZooZ::Generic::popMessage
      ($MW => "Perl code exported successfully to $f.", 1500);
}

__END__

=pod

=head1 NAME

ZooZ.pl - A Perl/Tk GUI builder in pure Perl/Tk.

=head1 SYNOPSIS

    % perl ZooZ.pl

=head1 DESCRIPTION

ZooZ is a GUI builder for Perl/Tk written in pure Perl/Tk. It has the
following features:

=over 4

=item *

Intuitive interface.

=item *

Support for a wide variety of widgets.

=item *

Ability to save/load projects.

=item *

Ability to dump stand-alone Perl code.

=item *

Includes a simple IDE for defining variables and subroutines.

=back

=head1 STATUS AND LIMITATIONS

Currently, ZooZ.pl is still in beta. So use at your own risk. At this stage, though,
I consider it to be very usable. There are some major limitations though. Here is
a list of the ones I consider major, and will probably fix before a 1.0 release. For
a more comprehensive list of missing features, you can look into the Progress.txt
file that comes in the root directory of the distribution.

=over 4

=item *

The preview window displays all widgets with borderwidth of 1. The dumped Perl code
has it set to 2.

=item *

No support, yet, for user-defined widgets.

=item *

User can not change widget names.

=item *

No way to define bindings.

=item *

No way to set MainWindow properties.

=back

=head1 REQUIREMENTS

To run ZooZ, you need Tk804, which in turn needs Perl 5.8 or better.
I will probably support Tk800 sometime in the future, in which case
any Perl5 version will be supported.

In addition Tk::ToolBar is required. Again, I will probably make this
optional in a future release.

=head1 OPTIONAL COMPONENTS

Tk::CodeText is optional. If present it will be used in the simple
IDE to highlight user-entered Perl code. If missing, a regular
Tk::Text will be used.

=head1 TIPS

=over 4

=item *

ZooZ automatically defines a hash called I<%ZWIDGETS> that holds the project's
widgets. This allows the user to access any widget inside of a callback via
I<$ZWIDGETS{WidgetName}> where B<WidgetName> is the name of the widget.

=item *

You can click on the row and column numbers to configure their properties.

=item *

If you want a row or column to take up more space than it currently does,
then increase its greediness. Remember that widgets are confined to the
space of the grids they occupy.

=back

=head1 BUGS

You tell me! If you think you found a bug, or you want to discuss anything
ZooZ-related, then please drop me a note at I<aqumsieh@cpan.org>.

=head1 ACKNOWLEDGEMENTS

I'm indebted to everyone on comp.lang.perl.tk for constructive comments and
bug reports.

=head1 COPYRIGHTS

Copyright 2004 - Ala Qumsieh.

This program is distributed under the same terms as Perl itself.

=end
