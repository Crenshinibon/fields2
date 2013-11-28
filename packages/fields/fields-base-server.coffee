#remove all forms at startup, requires reinitialization
Meteor.startup () ->
    Fields.forms.remove {}

Meteor.publish 'forms', () ->
    Fields.forms.find()

Fields.initForm = (form, formSpec, lang) ->
    Fields.forms.remove {form: form}
    Fields.forms.insert
        form: form
        formSpec: formSpec
        lang: lang
            
    Fields._initSubForm form, formSpec, form
    
    
Fields._initSubForm = (field, fieldSpec, path) ->
    for subField, subFieldSpec of fieldSpec
        Fields.initField subField, subFieldSpec, path

Fields._initMultiForm = (field, fieldSpec, path) ->
    fieldPath = path + '.' + field
    multiSpec = fieldSpec.element
    Fields.initField 'element', multiSpec, fieldPath
    
Fields._initCollection = (fp) ->
    #console.log fp
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
                Fields._initMultiForm field, fieldSpec, path
   