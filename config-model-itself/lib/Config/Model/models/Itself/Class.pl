# $Author$
# $Date$
# $Revision$

#    Copyright (c) 2007-2008 Dominique Dumont.
#
#    This file is part of Config-Model-Itself.
#
#    Config-Model-Itself is free software; you can redistribute it
#    and/or modify it under the terms of the GNU Lesser Public License
#    as published by the Free Software Foundation; either version 2.1
#    of the License, or (at your option) any later version.
#
#    Config-Model-Itself is distributed in the hope that it will be
#    useful, but WITHOUT ANY WARRANTY; without even the implied
#    warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#    See the GNU Lesser Public License for more details.
#
#    You should have received a copy of the GNU Lesser Public License
#    along with Config-Model-Itself; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA

[
  [
   name => "Itself::Class",

   class_description => "Configuration class. This class will contain elements",

   'element' 
   => [

       'element' => {
		     type       => 'hash',
		     level      => 'important',
		     ordered    => 1,
		     index_type => 'string',
		     cargo => { type => 'node',
				config_class_name => 'Itself::Element',
			      },
		    },

       'include' => { type => 'list',
		      cargo => {
				type => 'leaf',
				value_type => 'reference',
				refer_to => '! class',
			       }
		    } ,

       'include_after' => { type => 'leaf',
			    value_type => 'reference',
			    refer_to => '- element',
			  } ,

       'class_description'
       => { 
	   type => 'leaf',
	   value_type => 'string' ,
	  },

       [qw/generated_by write_config_dir read_config_dir/]
       => { 
	   type => 'leaf',
	   value_type => 'uniline' ,
	  },

       [qw/read_config write_config/]
       => {
	   type => 'list',
	   cargo => { type => 'node',
		      config_class_name => 'Itself::ConfigWR',
		    },
	  },

      ],

   'description' 
   => [
       element => "Specify the elements names of this configuration class.",
       include => "Include the specification of another class into this class.",
       include_after => "insert the included elements after a specific element" ,
       class_description => "Explain the purpose of this configuration class",
       write_config_dir => "Specify where to write configuration data",
       read_config_dir => "Specify where to read configuration data",
       read_config => "Specify the Perl class(es) and function(s) used to read configuration data. The specified function will be tried in sequence to get configuration data. " ,
       write_config => "Specify the Perl class and function used to write configuration data." ,
       generated_by => "When set, this class was generated by some program. You should not edit it as your modification may be clobbered later on",
      ],
  ],
  [
   name => "Itself::ConfigWR",

   'element' 
   => [
       'syntax' => { type => 'leaf',
		     value_type => 'enum',
		     choice => [qw/cds perl ini custom/],
		     description => 'specifies the syntax of the configuration data.',
		     help => {
			      cds => "config data string. This is Config::Model own serialisation format, designed to be compact and readable.",
			      ini => "Ini file format. Beware that the structure of your model must match the limitations of the INI file format, i.e only a 2 levels hierarchy",
			      perl => "perl data structure",
			      custom => "Custom format. You must specify your own class and method to perform the read or write function. See Config::Model::AutoRead doc for more details",
			     }
		   },

       [qw/class function/]
       => { 
	   type => 'leaf',
	   value_type => 'uniline' ,
	   level => 'hidden',
	   warp => { follow => '- syntax',
		     rules => [ custom => { level => 'normal',
					    mandatory => 1,
					  }
			      ],
		   }
	  },

      ],

  ],

];
