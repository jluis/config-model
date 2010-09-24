[
          {
            'name' => 'Debian::Dep5::Content',
            'element' => [
                           'Copyright',
                           {
                             'cargo' => {
                                          'value_type' => 'uniline',
                                          'match' => '[\\d\\-\\,]+, .*',
                                          'type' => 'leaf'
                                        },
                             'type' => 'list',
                             'description' => 'One or more free-form copyright statement(s) that apply to the files matched by the above pattern. If a work has no copyright holder (i.e., it is in the public
        domain), that information should be recorded here.
'
                           },
                           'License',
                           {
                             'type' => 'node',
                             'config_class_name' => 'Debian::Dep5::License'
                           }
                         ]
          }
        ]
;
