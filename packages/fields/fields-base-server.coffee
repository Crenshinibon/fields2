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

Fields._initCollection = (fp) ->
    console.log fp
    [collection, created] = Fields._getCollection fp
    if created
        Meteor.publish fp, (refId) ->
            collection.find {refId: refId}

Fields.initField = (field, fieldSpec, path) ->
    fieldPath = path + '.' + field
    if fieldSpec.type? 
        if fieldSpec.type is 'group'
            Fields._initSubForm field, fieldSpec.elements, fieldPath += '.elements'
        else
            Fields._initCollection fieldPath
            if fieldSpec.type is 'multi'
                Fields._initCollection fieldPath + '.element'
    
   