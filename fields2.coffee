Proposals = new Meteor.Collection 'proposals'


projectTypes = () ->
    ['Simple', 'Complex']

proposalForm = 
    summary: 
        label: 'Management Summary'
        type: 'richtext'
        default: 'Some Description'
        comments: true
    projectType: 
        label: 'Project Type'
        type: 'select'
        choices: projectTypes()
    cost:
        label: 'Costs'
        type: 'number'
    risks:
        label: 'Risks'
        type: 'complex'
        elements:
            name: 
                label: 'Name'
                type: 'simpletext'
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
        Proposals.remove {}
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
            
            
        