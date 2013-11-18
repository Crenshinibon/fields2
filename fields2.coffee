Proposals = new Meteor.Collection 'proposals'


projectTypes = () ->
    ['Simple', 'Complex']

proposalForm = 
    summary: 
        label: 'Management Summary'
        type: 'richtext'
        comments: true #specify a subform name
    justification:
        label: 'Justification'
        type: 'richtext'
        comments: true #specifiy a subform name
    projectType: 
        label: 'Project Type'
        type: 'select'
        choices: projectTypes()
    codeName: 
        label: 'Code Name'
        type: 'simpletext'
        default: 'None'
        hint: 'You can give your project a code name.'
    cost:
        label: 'Costs'
        type: 'number'
        inputClass: 'input-small'
        hint: 'Enter the estimated costs engaging this project.'
    milestones:
        label: 'Milestones'
        type: 'multi'
        element:
            label: 'Name'
            type: 'simpletext'
    risks:
        label: 'Risks'
        type: 'group'
        elements:
            name: 
                label: 'Name'
                type: 'simpletext'
                default: 'New Risk'
            probability:
                label: 'Probability'
                type: 'select'
                default: 'Medium'
                choices: ['High','Medium','Low']
            desc:
                label: 'Description'
                typ: 'richtext'

if Meteor.isServer
    
    Meteor.startup () ->
        Fields.initForm 'proposal', proposalForm
    
    
    Meteor.startup () ->
        if Proposals.find().count() is 0
            Proposals.insert
                name: 'The Ring'
            Proposals.insert
                name: 'The Others'
            Proposals.insert
                name: 'Texas Chainsaw Massacre'
    
    Meteor.publish 'proposals', () ->
        Proposals.find()
    

if Meteor.isClient
    
    Meteor.subscribe 'proposals'
    
    Template.main.proposals = () ->
        Proposals.find()
        
    Template.main.selectedProposal = () ->
        pId = Session.get 'selectedProposal'
        Proposals.findOne {_id: pId}
    
    Template.main.events
        'click tr.proposal': (e) ->
            Session.set 'selectedProposal', @_id
            
            
        