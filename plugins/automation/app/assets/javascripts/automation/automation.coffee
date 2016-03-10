@init_tag_editor_inputs= () ->
  $('textarea[data-toggle="tagEditor"][data-tageditor-type="key-value"]').each ->
    $(this).tagEditor({ placeholder: $(this).attr('placeholder') || 'Enter key value pairs' })
  $('textarea[data-toggle="tagEditor"][data-tageditor-type="tag"]').each ->
    $(this).tagEditor({ placeholder: $(this).attr('placeholder') || 'Enter tags', keyValueEntries: false })

@init_hint_popover= () ->
  $('[data-toggle="popover"][data-popover-type="help-hint"]').popover
    placement: 'top'
    trigger: 'focus'

@switch_automation_type=(event) ->
  value = event.target.value
  if value == 'chef'
    $('#chef-automation').removeClass('hide')
    $('#script-automation').addClass('hide')
  else if value == 'script'
    $('#script-automation').removeClass('hide')
    $('#chef-automation').addClass('hide')


$ ->
  # add handler to the show modal event
  $(document).on('modal:shown_success', init_tag_editor_inputs)

  # add handler to the show modal event
  $(document).on('modal:shown_success', init_hint_popover)

  # add handler to the automation type select
  $(document).on 'change','select[data-toggle="automationSwitch"]', switch_automation_type

  # init in case the content is not in modal
  init_tag_editor_inputs()
  init_hint_popover()