# $Author: ddumont $
# $Date: 2008-01-23 11:17:36 $
# $Name: not supported by cvs2svn $
# $Revision: 1.2 $

#    Copyright (c) 2007 Dominique Dumont.
#
#    This file is part of Config-Model-TkUi.
#
#    Config-Model is free software; you can redistribute it and/or
#    modify it under the terms of the GNU Lesser Public License as
#    published by the Free Software Foundation; either version 2.1 of
#    the License, or (at your option) any later version.
#
#    Config-Model is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#    Lesser Public License for more details.
#
#    You should have received a copy of the GNU Lesser Public License
#    along with Config-Model; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA

package Config::Model::TkUi ;

use strict;
use warnings ;
use Carp ;

use base qw/ Tk::Toplevel /;
use vars qw/$VERSION/ ;
use subs qw/menu_struct/ ;
use Tk::Multi::Manager ;
use Tk::Multi::Text ;
use Tk::Multi::Frame ;
use Scalar::Util qw/weaken/;

$VERSION = sprintf "%d.%03d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/;

Construct Tk::Widget 'ConfigModelUi';

sub ClassInit {
    my ($cw, $args) = @_;
    # ClassInit is often used to define bindings and/or other
    # resources shared by all instances, e.g., images.

    # cw->Advertise(name=>$widget);
}

sub Populate { 
    my ($cw, $args) = @_;

    foreach my $parm (qw/-root/) {
	my $attr = $parm ;
	$attr =~ s/^-//;
	$cw->{$attr} = delete $args->{$parm} 
	  or croak "Missing $parm arg\n";
    }

    # check unknown parameters
    croak "Unknown parameter ",join(' ',keys %$args) if %$args;

    # initialize internal attributes
    $cw->{location} = 'foobar';

    $cw->setup_scanner() ;

    # create top menu
    require Tk::Menubutton ;
    my $menubar = $cw->Menu ;
    $cw->configure(-menu => $menubar ) ;

    my $file_items = [[ qw/command reload -command/, sub{ $cw->reload }]] ;
    $menubar->cascade( -label => 'File', -menuitems => $file_items ) ; 

    my $perm_ref = $cw->{scanner}->get_permission_ref ;
    my $perm_items = [
		      map {['radiobutton',$_,'-variable', $perm_ref,
			    -command => sub{$cw->reload ;} 
			   ] }
		          qw/master advanced intermediate/
		     ] ;
    my $opt_items = [[qw/cascade permission -menuitems/, $perm_items ]] ;
    $menubar->cascade( -label => 'Options', -menuitems => $opt_items ) ; 

    # create frame for location entry 
    my $loc_frame = $cw -> Frame (-relief => 'sunken', -borderwidth => 1)
                        -> pack  (-pady => 0,  -fill => 'x' ) ;
    $loc_frame->Label(-text => 'location :') -> pack ( -side => 'left');
    $loc_frame->Label(-textvariable => \$cw->{location}) -> pack ( -side => 'left');

    # add bottom frame 
    my $bottom_frame = $cw->Frame 
      ->pack  (qw/-pady 0 -fill both -expand 1/ ) ;

    # create the widget for tree navigation 
    require Tk::Tree;
    my $tree = $bottom_frame 
      -> Scrolled ( qw/Tree/,
		    -columns =>3, -header => 1,
		    -browsecmd => sub{$cw->on_browse(@_) ;},
		    -command   => sub{$cw->on_select(@_) ;},
		    -opencmd   => sub{$cw->open_item(@_) ;},
		  )
      -> pack ( qw/-fill both -expand 1 -side left/) ;
    $cw->{tktree} = $tree ;

    # add adjuster
    require Tk::Adjuster;
    $bottom_frame -> Adjuster()->packAfter($tree, -side => 'left') ;

    # add headers
    $tree -> headerCreate(0, -text => "element") ;
    $tree -> headerCreate(1, -text => "value") ;
    $tree -> headerCreate(2, -text => "standard value") ;

    $cw->reload ;

    # add frame on the right for entry and help
    my $eh_frame = $bottom_frame -> Frame -> pack (qw/-fill both -expand 1 -side left/) ;
    $cw->{eh_frame} = $eh_frame ;

    # add entry frame, filled by call-back
    # should be a composite widget
    $cw->{e_frame} = $eh_frame -> Frame -> pack (qw/-side top -fill both -expand 1/) ;
    $cw->{e_frame} ->Label(-text => "placeholder") -> pack ;

    # Note: e_frame is not resised when adding editor widget if Adjuster is used

    # add help1 text
    require Tk::ROText;
    my $help1 = $eh_frame -> ROText(-height => 10 ) 
      -> pack (qw/-side bottom -fill both -expand 1/);
    $help1->tagConfigure("underline", -underline =>1 );
    $cw->{help_frame}= $help1;

    #$eh_frame ->  Adjuster()->packAfter($help1, -side => 'top') ;
    #my $help2 = $eh_frame -> ROText(-height => 10 ) -> pack (qw/-side top -fill x/);

    # bind double click to create editor widget
    #$tree->bind('<Double-Button-1>', sub{$cw->create_modify_widget()}) ;

    $cw->ConfigSpecs
      (
       #-background => ['DESCENDANTS', 'background', 'Background', $background],
       #-selectbackground => [$hlist, 'selectBackground', 'SelectBackground', 
       #                      $selectbackground],
       -width  => [$tree, undef, undef, 80],
       -height => [$tree, undef, undef, 25],
       #-oldcursor => [$hlist, undef, undef, undef],
       DEFAULT => [$tree]
      ) ;

    $cw->Advertise(tree => $tree,
		   ed_frame => $cw->{e_frame} ,
		  );

    $cw->SUPER::Populate($args) ;
}

# Note: this callback is called by Tk::Tree *before* changing the
# indicator. And the indicator is used by Tk::Tree to store the
# open/close/none mode. So we can't rely on getmode for path that are
# opening. HEnce the parameter passed to the sub stored with each
# Tk::Tree item
sub open_item {
    my ($cw,$path) = @_ ;
    my $tktree = $cw->{tktree} ;
    print "open_item on $path\n";
    my $data = $tktree -> infoData($path);

    # invoke the scanner part (to create children)
    # the parameter indicates that we are opening this path
    $data->[0]->(1) ;

    my @children = $tktree->infoChildren($path) ;
    print "open_item show @children\n";
    map { $tktree->show (-entry => $_); } @children ;
}

sub reload {
    my $cw =shift ;
    my $tree = $cw->{tktree} ;

    my $instance_name = $cw->{root}->instance->name ;

    my $new_drawing = not $tree->infoExists($instance_name) ;

    my $sub 
      = sub {$cw->{scanner}->scan_node([$instance_name,$cw,@_],$cw->{root}) ;};

    if ($new_drawing) {
	$tree->add($instance_name, -text => $instance_name , 
		   -data => [ $sub,  $cw->{root} ] ); 
	$tree->setmode($instance_name,'close') ;
	$tree->open($instance_name) ;
    }

    $sub->(0) ; # the parameter indicates that we are not opening the root
}


# call-back when Tree element is selected
sub on_browse {
    my ($cw,$path) = @_ ;
    #$cw->{path}=$path ;
    my $datar = $cw->{tktree}->infoData($path) ;
    my $obj = $datar->[1] ;
    $cw->add_help($obj) ;
    $cw->{location} = $obj->location;
}

sub on_select {
    my ($cw,$path) = @_ ;
    $cw->on_browse($path) ;
    $cw->create_modify_widget() ;
}


# replace dot in str by ___
sub to_path   { my $str  = shift ; $str  =~ s/\./_|_/g; return $str ;}
sub from_path { my $path = shift ; $path =~ s/_|_/./g ; return $path; }

sub prune {
    my $cw = shift ;
    my $path = shift ;
    print "prune $path\n";
    my %list = map { "$path." . to_path($_) => 1 } @_ ;
    # remove entries that are not part of the list
    my $tkt = $cw->{tktree} ;

    map { 
	$tkt->deleteEntry($_) if $_ and not defined $list{$_} ;
    }  $tkt -> infoChildren($path) ;
    print "prune $path done\n";
}

# Beware: TkTree items store tree object and not tree cds path. These
# object might become irrelevant when warp master values are
# modified. So the whole Tk Tree layout must be redone very time a
# config value is modified. This is a bit heavy, but a smarter
# alternative would need hooks in the configuration tree to
# synchronise the Tk Tree with the configuration tree :-p

my %elt_mode = ( leaf => 'none',
		 hash => 'open',
		 list => 'open',
		 node => 'open',
		 check_list => 'none',
		 warped_node => 'open',
	       );

sub disp_obj_elt {
    my ($scanner, $data_ref,$node,@element_list) = @_ ;
    my ($path,$cw,$opening) = @$data_ref ;
    my $tkt = $cw->{tktree} ;
    my $mode = $tkt -> getmode($path) ;
    print "disp_obj_elt path $path mode $mode (@element_list)\n";

    $cw->prune($path,@element_list) ;

    my $prevpath = '' ;
    foreach my $elt (@element_list) { 
	my $newpath = "$path." . to_path($elt) ;
	my $scan_sub = sub { 
	    $scanner->scan_element([$newpath,$cw,@_], $node,$elt) ;
	} ;
	my @data = ( $scan_sub, $node -> fetch_element($elt) );

	# It's necessary to store a weakened reference of a tree
	# object as these ones tend to disappear when warped out. In
	# this case, the object must be destroyed. This does not
	# happen if a non-weakened reference is kept in Tk Tree.
	weaken( $data[1] );

	unless ($tkt->infoExists($newpath)) {
	    my @opt = $prevpath ? (-after => $prevpath) : () ;
	    my $elt_type = $node->element_type($elt) ;
	    my $newmode = $elt_mode{$elt_type};
	    print "disp_obj_elt add $newpath mode $newmode type $elt_type\n";
	    $tkt->add($newpath, -text => $elt , -data => \@data, @opt) ;
	    $tkt -> setmode($newpath => $newmode) ;
	    # hide new entry if node is not yet opened
	    $tkt->hide(-entry => $newpath) if $mode eq 'open' ;
	}
	# counterintuitive but right: scan will be done when the entry
	# is opened
	$scan_sub->(0) if ($opening or $mode ne 'open') ; 
	$prevpath = $newpath ;
    } ;
}

sub disp_hash {
    my ($scanner, $data_ref,$node,$element_name,@idx) = @_ ;
    my ($path,$cw,$opening) = @$data_ref ;
    my $tkt = $cw->{tktree} ;
    my $mode = $tkt -> getmode($path) ;
    print "disp_hash    path is $path  mode $mode (@idx)\n";

    $cw->prune($path,@idx) ;

    my $elt = $node -> fetch_element($element_name) ;

    my $prevpath = '' ;
    foreach my $idx (@idx) {
	my $newpath = $path.'.'. to_path($idx) ;
	my $scan_sub = sub {
	    $scanner->scan_hash([$newpath,$cw,@_],$node, $element_name,$idx);
	};
	my @data = ( $scan_sub, $elt->fetch_with_id($idx) );
	weaken($data[1]) ;

	unless ($tkt->infoExists($newpath)) {
	    my @opt = $prevpath ? (-after => $prevpath) : () ;
	    my $elt_type = $elt->get_cargo_type();
	    my $newmode = $elt_mode{$elt_type};
	    print "disp_hash add $newpath mode $newmode cargo_type $elt_type\n";
	    $tkt->add($newpath, -text => $idx , -data => \@data, @opt) ;
	    $tkt -> setmode($newpath => $newmode) ;
	    # hide new entry if hash is not yet opened
	    $tkt->hide(-entry => $newpath) if $mode eq 'open' ;
	    #my $curmode = $tkt->getmode($path);
	}

	my $idx_mode = $tkt->getmode($newpath) ;
	print "disp_hash   sub path $newpath is mode $idx_mode\n";
	$scan_sub->(0) if ($opening or $idx_mode eq 'open') ;

	$prevpath = $newpath ;
    } ;
}

sub disp_leaf {
    my ($scanner, $data_ref,$node,$element_name,$index, $leaf_object) =@_;
    my ($path,$cw,$opening) = @$data_ref ;
    print "disp_leaf    path is $path\n";

    my $value_type = $leaf_object->value_type ;
    my $value = $leaf_object->fetch_no_check ;
    my @opt ;
    if ($leaf_object->check($value) ) {
	push @opt, -itemtype => 'imagetext' , -image => $cw->Getimage('warning') ;
    }
    $cw->{tktree}->itemCreate($path,1,-text => $value, @opt) ;

    my $std_v = $leaf_object->fetch('standard') ;
    $cw->{tktree}->itemCreate($path,2, -text => $std_v) ;
}

sub disp_node {
    my ($scanner, $data_ref,$node,$element_name,$key, $contained_node) = @_;
    my ($path,$cw,$opening) = @$data_ref ;
    print "disp_node    path is $path\n";
    my $curmode = $cw->{tktree}->getmode($path);
    $cw->{tktree}->setmode($path,'open') if $curmode eq 'none';

    # explore next node 
    $scanner->scan_node($data_ref,$contained_node);
}


sub setup_scanner {
    my ($cw) = @_ ;
    require Config::Model::ObjTreeScanner ;

    my $scanner = Config::Model::ObjTreeScanner->new 
      (

       fallback => 'node',
       permission => 'master', #'intermediate', 

       # node callback
       node_content_cb       => \&disp_obj_elt ,

       # element callback
       list_element_cb       => \&disp_hash    ,
       check_list_element_cb => \&disp_leaf    ,
       hash_element_cb       => \&disp_hash    ,
       node_element_cb       => \&disp_node     ,

       # leaf callback
       leaf_cb               => \&disp_leaf,
       enum_value_cb         => \&disp_leaf,
       enum_integer_value_cb => \&disp_leaf,
       integer_value_cb      => \&disp_leaf,
       number_value_cb       => \&disp_leaf,
       boolean_value_cb      => \&disp_leaf,
       string_value_cb       => \&disp_leaf,
       uniline_value_cb      => \&disp_leaf,
       reference_value_cb    => \&disp_leaf,

       # call-back when going up the tree
       up_cb                 => sub {} ,
      ) ;

    $cw->{scanner} = $scanner ;

}

sub create_modify_widget {
    my $cw = shift ;
    my $item = shift ; # reserved for tests

    my $tree = $cw->{tktree};

    unless (defined $item)
      {
        # pointery and rooty are common widget method and must called on
        # the right widget to give accurate results
        $item = $tree->nearest($tree->pointery - $tree->rooty) ;
      }

    $tree->selectionClear() ; # clear all
    $tree->selectionSet($item) ;
    my $data_ref = $tree->infoData($item);
    unless (defined $data_ref->[1]) {
	$cw->reload;
	return;
    }
    my $loc = $data_ref->[1]->location;

    my $obj = $cw->{root}->grab($loc);
    my $type = $obj -> get_type ;
    print "item $loc to modify (type $type)\n";

    # cleanup existing widget contained in this frame
    map { $_ ->destroy if Tk::Exists($_) } $cw->{e_frame}->children ;

    my $frame = $cw->{e_frame} ;

    if ($type eq 'leaf') {
	require Config::Model::Tk::LeafEditor ;
	$frame->ConfigModelLeafEditor(-leaf => $obj)->pack ;
    }
    elsif ($type eq 'check_list') {
	require Config::Model::Tk::CheckListEditor ;
	$frame->ConfigModelCheckListEditor(-leaf => $obj)->pack ;
    }
    elsif ($type eq 'list' or $type eq 'hash') {
	require Config::Model::Tk::ListEditor ;
	$frame->ConfigModelListEditor(-list => $obj)->pack ;
    }
}

sub add_help {
    my $cw = shift ;
    my $obj = shift ;

    my $help_w = $cw->{help_frame};
    $help_w->delete('1.0','end') ;

    my $node = $obj->parent ;
    my $class_obj = $node || $obj ;

    my @help = ("class:\n", 'underline',
		$class_obj->get_help, 'class_help') ;
    push @help ,   "\n\n", 'sep', "element:\n", 'underline',
      $node->get_help($obj->element_name), 'element_help'
	if defined $node ;
    $help_w->insert('end', @help ) ;
}


1;
