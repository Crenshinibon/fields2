#remove all forms at startup, requires reinitialization
Meteor.startup () ->
    Fields.forms.remove {}

Meteor.publish 'forms', () ->
    Fields.forms.find()

Fields.initForm = (form, formSpec) ->
    Fields.forms.insert
        form: form
        formSpec: formSpec
            
    Fields._initSubForm form, formSpec, 'formSpec'
    
    
Fields._initSubForm = (field, fieldSpec, path) ->
    for subField, subFieldSpec of fieldSpec
        Fields.initField subField, subFieldSpec, path


Fields.initField = (field, fieldSpec, path) ->
    fieldPath = path + '.' + field
    if fieldSpec.type? 
        if fieldSpec.type is 'complex'
            Fields._initSubForm field, fieldSpec.elements, fieldPath += '.elements'
        
        else
            console.log fieldPath
            [collection, created] = Fields._getCollection fieldPath
            if created
                Meteor.publish fieldPath, (refId) ->
                    collection.find {refId: refId}
    
   