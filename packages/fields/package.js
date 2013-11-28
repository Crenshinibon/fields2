Package.describe({
   summary: 'A package to provide convenient, self managing form fields' 
});

Package.on_use(function (api) {
   api.use('standard-app-packages', ['client', 'server']);
   api.use('coffeescript',['client','server']);
   
   //libs
   api.add_files('bootstrap-wysiwyg/bootstrap-wysiwyg.js', 'client');
   api.add_files('bootstrap-wysiwyg/jquery.hotkeys.js', 'client');
   api.add_files('bootstrap-wysiwyg/styles.css','client');
   //api.export('wysiwyg');
   
   api.add_files('momentjs/moment-with-langs.js','client');
   //api.export('moment');
   
   api.add_files('namespace.coffee',['client', 'server']);
   api.export('Fields');
   
   api.add_files('fields-templates.html','client');
   
   api.add_files('fields-base.coffee', ['server','client']);
   api.add_files('fields-values-client.coffee', 'client');
   api.add_files('fields-base-client.coffee', 'client');
   api.add_files('fields-base-server.coffee', 'server');
   
   //api.add_files('form-client.coffee','client');
});