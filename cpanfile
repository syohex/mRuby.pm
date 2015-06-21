requires 'parent';
requires 'perl', '5.008008';
requires 'Exporter', '5.57';

on build => sub {
    requires 'Cwd::Guard';
    requires 'File::Which';
    requires 'Module::Build::XSUtil';
};

on test => sub {
    requires 'Test::More';
};

on develop => sub {
    requires 'Test::Requires';
};
