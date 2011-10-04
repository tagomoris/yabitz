$(function(){
    var h = $('#mainview').height();
    $('#detailview').height(h);
    $('#detailboxarea').height(h);
    
    $('#nav').droppy();
    $('#searchinput').keypress(function(e){if(e.which == 13){$('#smartsearch').submit();};});

    // toolbox operations
    $('button#select_on_all').click(function(e){
        clear_selections();
        $('.selectable').each(function(){select_on_selectable($(this));});
        $('#detailbox').hide();
    });
    $('button#select_off_all').click(function(e){
        $('#detailbox').hide();
        clear_selections();
    });
    $('button#selected_hosts').click(function(e){show_selected_hosts(e);});
    $('button#hosts_history').click(function(e){show_hosts_history(e);});
    $('button#hosts_diff').click(function(e){show_hosts_diff(e);});
    $('button#opetaglist').click(function(e){show_operations(e);});
    $('button#bricks_of_hosts').click(function(e){show_bricks_of_hosts(e);});

    $('button#selected_bricks').click(function(e){show_selected_bricks(e);});
    $('button#bricks_history').click(function(e){show_bricks_history(e);});

    $('div#copypasterlinks').find('.copypaster').click(function(e){
        copypastable_all_hosts($(e.target), window.location.href);
    });

    // events for main table items
    $('.host_outline.selectable').click(function(e){toggle_item_selection(e, 'host');});
    $('.service_item.selectable').click(function(e){toggle_item_selection(e, 'service', true);});
    $('.service_item.unselectable').click(function(e){show_detailbox_without_selection(e, 'service');});
    $('.content_item.selectable').click(function(e){toggle_item_selection(e, 'content', true);});
    $('.dept_item.selectable').click(function(e){toggle_item_selection(e, 'dept', true);});
    $('.rack_item.selectable').click(function(e){toggle_item_selection(e, 'rack', true);});
    $('.ipaddress_item.selectable').click(function(e){toggle_item_selection(e, 'ipaddress', true);});
    $('.ipsegment_item.selectable').click(function(e){toggle_item_selection(e, 'ipsegment', true);});
    $('.authinfo_item.selectable').click(function(e){toggle_item_selection(e, 'auth_info');});
    $('.charge_item.selectable').click(function(e){toggle_item_selection(e, 'charge/content', true);});
    $('.machine_item.hw.selectable').click(function(e){toggle_item_selection(e, 'machines/hardware', true);});
    $('.machine_item.os.selectable').click(function(e){toggle_item_selection(e, 'machines/os', true);});
    $('.opetag_item.selectable').click(function(e){toggle_item_selection(e, 'host/operation', true);});
    $('.contactmember_item.selectable').click(function(e){toggle_item_selection(e, 'contactmember');});
    $('.brick_item.selectable').click(function(e){toggle_item_selection(e, 'brick');});
    $('.brick_item.unselectable').click(function(e){show_detailbox_without_selection(e, 'brick');});

    // events for mainview toggle
    $('.show_mainview').click(function(event){
        $(event.target).closest('#editpain1,#editpain2').addClass('hidden');
        $('#maincontents').removeClass('hidden');
    });
    $('.show_editpain1').click(function(event){$('#maincontents').addClass('hidden'); $('#editpain1').removeClass('hidden');});
    $('.show_editpain2').click(function(event){$('#maincontents').addClass('hidden'); $('#editpain2').removeClass('hidden');});

    // event for cloneable items add button
    $('div.listclone').click(function(e){clone_cloneable_item(e);});

    // events for entry-creation (host, contactmember, contact)
    $('form.mainform').submit(function(e){commit_main_form(e);});
    $('button.mainform_commit').click(function(e){$(e.target).closest('form.mainform').submit();});

    // events for edit contact (member-add/remove, re-ordering)


    // top page search
    $('#googlelikeinput').keypress(function(e){if(e.which == 13){e.preventDefault(); return false;} return true;});
    $('button.search_googlelike').click(function(e){
        var button = $(e.target).closest('button.search_googlelike');
        var param = button.closest('form.mainform_googlelike').formSerialize() + '&field0=' + button.attr('title');
        window.location.href = '/ybz/search?' + param;
        e.preventDefault();
        return false;
    });
    $('button.search_googlelike_smart').click(function(e){
        var button = $(e.target).closest('button.search_googlelike_smart');
        var param = $('input#googlelikeinput').val();
        window.location.href = '/ybz/smartsearch?keywords=' + param;
        e.preventDefault();
        return false;
    });

    // admin events for mainview
    $('form.smartadd').submit(function(e){commit_smartadd_form(e);});
    $('select.admin_operations').change(function(e){dispatch_admin_operation(e);});

    if ($('div.default_selected_all').size() > 0) {
        $('button#select_on_all').click();
    }

    ZeroClipboard.setMoviePath( '/zeroclipboard/ZeroClipboard10.swf' );
});

$.fn.hoverClass = function(c) {
    return this.each(function(){
	$(this).hover( 
	    function() { $(this).addClass(c);  },
	    function() { $(this).removeClass(c); }
	);
    });
};

function regist_event_listener(target){
    if (target.hasClass('host_outline')) {
        target.click(function(e){toggle_item_selection(e, 'host');});
    }
    if (target.hasClass('service_item')) {
        if (target.hasClass('selectable'))
            target.click(function(e){toggle_item_selection(e, 'service');});
        else if (target.hasClass('unselectable'))
            target.click(function(e){show_detailbox_without_selection(e, 'service');});
    }
    if (target.hasClass('content_item')) {
        target.click(function(e){toggle_item_selection(e, 'content', true);});
    }
    if (target.hasClass('dept_item')) {
        target.click(function(e){toggle_item_selection(e, 'dept', true);});
    }
    if (target.hasClass('rack_item')) {
        target.click(function(e){toggle_item_selection(e, 'rack', true);});
    }
    if (target.hasClass('ipaddress_item')) {
        target.click(function(e){toggle_item_selection(e, 'ipaddress', true);});
    }
    if (target.hasClass('ipsegment_item')) {
        target.click(function(e){toggle_item_selection(e, 'ipsegment', true);});
    }
    if (target.hasClass('contactmember_item')) {
        target.click(function(e){toggle_item_selection(e, 'contactmember');});
    }
    if (target.hasClass('brick_item')) {
        if (target.hasClass('selectable'))
            target.click(function(e){toggle_item_selection(e, 'brick');});
        else if (target.hasClass('unselectable'))
            target.click(function(e){show_detailbox_without_selection(e, 'brick');});
    }
    if (target.hasClass('authinfo_item')) {
        target.click(function(e){toggle_item_selection(e, 'auth_info');});
    }
};

if (!('bind_events_detailbox_addons' in window)) {
    bind_events_detailbox_addons = [];
}

function bind_events_detailbox() {
    $('.clickableitem,.dataview,.dataupdown,.orderedit').mouseover(function(e){highlight_editable_item(e);});
    $('.clickableitem,.dataview,.dataupdown,.orderedit').mouseout(function(e){un_highlight_editable_item(e);});

    $('div.clickablelabel,div.clickablebutton').click(function(e){show_editable_item(e);});
    $('div.memoeditbutton').click(function(e){show_editable_item(e);});

    $('img.itemadd').click(function(e){show_add_item(e);});
    $('input.togglebutton').click(function(e){e.preventDefault(); $(e.target).closest('form').submit(); return false;});

    $('form.field_edit_form').submit(function(e){commit_field_change(e);});
    $('form.toggle_form').submit(function(e){commit_toggle_form(e);});

    if (('bind_events_detailbox_addons' in window) && bind_events_detailbox_addons.length > 0) {
        $.each(bind_events_detailbox_addons, function(){ this(); });
    }
};

function commit_main_form(event){
    var form = $(event.target);
    if (form.attr('name') == 'host_create') {
        commit_mainview_form($(event.target), "ホスト追加に成功", function(){
            location.href = '/ybz/hosts/service/' + form.find('select[name="service"]').val();
        });
    }
    else if (form.attr('name') == 'host_search') {
        return true;
    }
    else if (form.attr('name') == 'host_search_dns') {
        return true;
    }
    else if (form.attr('name') == 'host_search_ip') {
        return true;
    }
    else if (form.attr('name') == 'host_search_service') {
        return true;
    }
    else if (form.attr('name') == 'host_search_rackunit') {
        return true;
    }
    else if (form.attr('name') == 'host_search_hwid') {
        return true;
    }
    else if (form.attr('name') == 'smart_search') {
        return true;
    }
    else if (form.attr('name') == 'contact_edit') {
        commit_mainview_form($(event.target), "連絡先の情報を更新しました", function(){
            location.href = '/ybz/contact/' + $('div#contact_oid div.contact_oid').attr('id');
        });
    }
    else if (form.attr('name') == 'contact_add_with_create') {
        commit_mainview_form($(event.target), "連絡先の情報を更新しました", function(){
            location.href = '/ybz/contact/' + $('div#contact_oid div.contact_oid').attr('id');
        });
    }
    else if (form.attr('name') == 'contact_add_with_search') {
        commit_mainview_form($(event.target), "連絡先の情報を更新しました", function(){
            location.href = '/ybz/contact/' + $('div#contact_oid div.contact_oid').attr('id');
        });
    }
    else if (form.attr('name') == 'contact_edit_memberlist') {
        commit_mainview_form($(event.target), "連絡先の情報を更新しました", function(){
            location.href = '/ybz/contact/' + $('div#contact_oid div.contact_oid').attr('id');
        });
    }
    else if (form.attr('name') == 'brick_create') {
        commit_mainview_form($(event.target), "機器追加に成功", function(){
            location.href = '/ybz/bricks/list/' + form.find('select[name="status"]').val().toLowerCase();
        });
    }
    else if (form.attr('name') == 'brick_bulkcreate') {
        commit_mainview_form($(event.target), "機器追加に成功", function(){
            location.href = '/ybz/bricks/list/' + form.find('select[name="status"]').val().toLowerCase();
        });
    }

    event.preventDefault();
    return false;
};

function show_selected_hosts(event){
    var selected = $(selected_objects());
    if (selected.size() < 1) {
        show_error_dialog("対象がなにも選択されていません");
        return false;
    };
    window.location.href = '/ybz/host/' + selected.get().join('-');
};

function show_bricks_of_hosts(event){
    var selected = $(selected_objects());
    if (selected.size() < 1) {
        show_error_dialog("対象がなにも選択されていません");
        return false;
    };
    window.location.href = '/ybz/brick/list/hosts/' + selected.get().join('-');
};

function show_selected_bricks(event){
    var selected = $(selected_objects());
    if (selected.size() < 1) {
        show_error_dialog("対象がなにも選択されていません");
        return false;
    };
    window.location.href = '/ybz/brick/' + selected.get().join('-');
};

function show_hosts_history(event){
    var selected = $(selected_objects());
    if (selected.size() < 1) {
        show_error_dialog("対象がなにも選択されていません");
        return false;
    };
    window.location.href = '/ybz/host/history/' + selected.get().join('-');
};

function show_bricks_history(event){
    var selected = $(selected_objects());
    if (selected.size() < 1) {
        show_error_dialog("対象がなにも選択されていません");
        return false;
    };
    window.location.href = '/ybz/brick/history/' + selected.get().join('-');
};

function show_hosts_diff(event){
    var oidlist = $("input[name='oidlist']").val();
    var before = $("input[type='radio']").filter("input[name='before']").filter(":checked").val();
    var after = $("input[type='radio']").filter("input[name='after']").filter(":checked").val();
    if (after == undefined && before == undefined) {
        show_error_dialog("開始点および終了点を選択してください");
        return false;
    }

    if (after == undefined || Number(after) < Number(before)) {
        var tmp = after;
        after = before;
        before = tmp;
    }
    var url = '/ybz/host/diff/' + oidlist + '/' + after;
    if (before != undefined) {
        url = url + '/' + before;
    }
    window.location.href =  url;
};

function show_operations(event){
    var start = $("input[name='start_date']").val();
    var end = $("input[name='end_date']").val();
    var url = "/ybz/operations";
    if (start != null && end != null) {
        if (start.length != 8 || end.length != 8) {
            alert("日付入力は8桁 yyyymmdd で入力してください");
            return false;
        }
        url = url + '/' + start + '/' + end;
    }
    window.location.href = url;
};

function load_page(url) { window.location.href = url; };

function reload_page(){
    window.location.reload(true);
};

function jump_opetag(tag) {
    window.location.href = '/ybz/host/operation/' + tag;
};

function show_confirm_dialog(msg, ok_callback, cancel_callback){
    var dialogbox = $('div#confirm_dialog');
    dialogbox.dialog({
        autoOpen: false,
        height: 250,
        width: 600,
        modal: true,
        buttons: {'OK': function(){dialogbox.dialog('close'); ok_callback();},
                  'キャンセル': function(){dialogbox.dialog('close'); cancel_callback();}}
    });
    dialogbox.children('div#dialogmessage').html(msg);
    dialogbox.dialog('open');
};

function show_form_dialog(url, form_content, success_callback, cancel_callback){
    var dialogbox = $('div#form_dialog');
    dialogbox.dialog({
        autoOpen: false,
        height: 250,
        width: 600,
        modal: true,
        buttons: {
            '送信': function(){
                $('#dialogform').ajaxSubmit({
                    url: url,
                    success: function(data, dataType){
                        dialogbox.dialog('close');
                        show_success_dialog('処理に成功しました', data, success_callback);
                    },
                    error: function(xhr, testStatus, error){
                        dialogbox.dialog('close');
                        show_error_dialog(xhr.responseText, cancel_callback);
                    }
                });
            },
            'キャンセル': function(){dialogbox.dialog('close'); cancel_callback();}
        }
    });
    dialogbox.find('div#dialogform_content').html(form_content);
    dialogbox.dialog('open');
};

function show_success_dialog(msg, result_tag, callback){
    var dialogbox = $('div#success_dialog');
    dialogbox.dialog({
        autoOpen: false,
        height: 250,
        width: 600,
        modal: true,
        buttons: {'OK': function(){dialogbox.dialog('close');}}
    });
    dialogbox.children('div#dialogmessage').html(msg + '<br />' + result_tag);
    if (callback) {
        if (result_tag.match(/^opetag:(.*)$/)) {
            var opetag = RegExp.$1;
            dialogbox.bind("dialogclose", function(event, ui){jump_opetag(opetag);});
        }
        else {
            dialogbox.bind("dialogclose", function(event, ui){callback(result_tag);});
        }
    }
    dialogbox.dialog('open');
};

function show_error_dialog(msg, callback){
    var dialogbox = $('div#error_dialog');
    dialogbox.dialog({
        autoOpen: false,
        height: 250,
        width: 600,
        modal: true,
        buttons: {'OK': function(){dialogbox.dialog('close');}}
    });
    dialogbox.children('div#dialogmessage').html(msg);
    if (callback) {
        dialogbox.bind("dialogclose", function(event, ui){callback();});
    }
    dialogbox.dialog('open');
};

function copypastable_setup(target, copypaster_type, baseurl, linkurl){
    if ($('embed#ZeroClipboardMovie_1').size() > 0) {
        $('embed#ZeroClipboardMovie_1').parent().remove();
    };
    $('li#paster').remove();

    var url = "";
    switch(copypaster_type) {
    case 'copypaster_s':
        url = baseurl + '.S.csv'; break;
    case 'copypaster_m':
        url = baseurl + '.M.csv'; break;
    case 'copypaster_l':
        url = baseurl + '.L.csv'; break;
    }
    $(target).closest('.copypaster').after('<li id="paster">[copy]</li>');
    $.get(url, function(data){
        var clip = new ZeroClipboard.Client();
        clip.setText(linkurl + "\n" + data);
        clip.glue('paster');
        $('#paster').click(function(e){$(e.target).remove();});
    });
    event.preventDefault();
    return false;
};

function copypastable_all_hosts(target, linkurl) {
    copypastable_setup(
        target,
        $(target).closest('.copypaster').attr('id'),
        '/ybz/host/' + $.map($('.host_outline.selectable'), function(v,i){return $(v).attr('id');}).join('-'),
        linkurl
    );
    event.preventDefault();
    return false;
};

function copypaster(event) {
    var hosts_url = '/ybz/host/' + selected_objects().join('-');
    copypastable_setup(
        event.target,
        $(event.target).closest('.copypaster').attr('id'),
        hosts_url,
        window.location.protocol + '//' + window.location.host + hosts_url
    );
    event.preventDefault();
    return false;
};

function update_selections_number(){
    var num = $('#selections').children().size();
    if (num == 0) {
        $('#selection_number').text('なし');
        $('.copypaster').unbind();
        $('#copypasterbox').hide();
    }
    else {
        $('#selection_number').text(num);
        $('#copypasterbox').show();
        $('.copypaster').unbind().click(copypaster);
    }
};

function clear_selections(){
    $('.selectable').each(function(){select_off_selectable($(this));});
    $('#selections').children().remove();
};

function add_to_selections(oid, disp_name){
    $('#selections').children('[title="' + oid + '"]').remove();
    $('#selections').append('<li title="' + oid + '">' + disp_name + '</li>');
    update_selections_number();
};
function remove_from_selections(oid){
    $('#selections').find('[title="' + oid + '"]').remove();
    update_selections_number();
};
function selected_objects(){
    return $.map($('#selections').children(), function(obj,i){ return $(obj).attr('title'); });
};

function select_on_selectable(target){
    var oid = target.attr("id");
    if (target.filter('.selected_item').size() > 0) {
        return;
    }
    target.addClass('selected_item').find(':checkbox').attr('checked', true);
    add_to_selections(oid, target.attr('title'));
};

function select_off_selectable(target){
    var oid = target.attr("id");
    if (target.filter('.selected_item').size() < 1) {
        return;
    }
    target.removeClass('selected_item').find(':checkbox').attr('checked', false);
    remove_from_selections(oid);
};

function show_detailbox_without_selection(event, modelname){
    var target = $(event.target).closest('.selectable,.unselectable');
    var oid = target.attr("id"); // in case of ipaddr, "id" has ipaddress string, instead of oid
    if (oid == null || oid == "") {return false; }
    show_detailbox(modelname, oid, event.pageY - detailbox_offset(), false);
};

function toggle_item_selection(event, modelname, single){
    var target = $(event.target).closest('.selectable');
    var oid = target.attr("id"); // in case of ipaddr, "id" has ipaddress string, instead of oid
    if (oid == null || oid == "") { return false; }

    var sibling_ids = target.parent().children().map(function(){return $(this).attr("id") || -1;});
    var target_obj_index = $.inArray(target.attr("id"), sibling_ids);

    if (single && target.filter('.selected_item').size() > 0) {
        select_off_selectable(target);
    }
    else if (single) {
        clear_selections();
        select_on_selectable(target);
    }
    else if (event.shiftKey && arguments.callee.last_clicked != undefined) {
        var listup = function(target, start, end) {
            if (end < start) { var tmp = end; end = start; start = tmp; }
            return $.grep(target.parent().children(), function(obj,i){return $(obj).filter('.selectable').size() > 0 && i >= start && i <= end;});
        };
        var start_obj_index = $.inArray($(selected_objects()).eq(-1).get()[0], sibling_ids);
        if (target.filter('.selected_item').size() > 0) {
            $(listup(target, start_obj_index, target_obj_index)).each(function(){select_off_selectable($(this));});
        }
        else {
            $(listup(target, start_obj_index, target_obj_index)).each(function(){select_on_selectable($(this));});
        }
    }
    else if (target.filter('.selected_item').size() > 0) {
        select_off_selectable(target);
    }
    else {
        select_on_selectable(target);
    }
    arguments.callee.last_clicked = target_obj_index;
    show_detailbox(modelname, oid, event.pageY - detailbox_offset(), false);
};

function reload_table_rows(type, oids){
    if (! $.isArray(oids)) {
        oids = [oids];
    }
    $.each(oids, function(i, oid){
        var oldtarget = $('tr#' + oid);
        if (oldtarget.filter('.unupdatable').size() > 0) {
            return;
        }
        oldtarget.addClass('obsolete_row');
        $.get('/ybz/' + type + '/' + oid + '.tr.ajax?t=' + (new Date()).getTime(), null, function(data){
            oldtarget.after(data);
            $('tr.obsolete_row#' + oid).remove();
            target = $('tr#' + oid);
            regist_event_listener(target);
            if ($('#selections').children('[title="' + oid + '"]').size() > 0) {
                target.addClass('selected_item').find(':checkbox').attr('checked', true);
                add_to_selections(oid, target.attr('title'));
            }

            orig_color = target.css('background-color');
            target.animate({backgroundColor:'yellow'}, 250, null, function(){
                target.animate({backgroundColor:orig_color}, 250, null, function(){
                    target.removeAttr('style');
                });
            });
        });
    });
};

function detailbox_offset(){
    var topmargin_h = $("#appheader").outerHeight();
    var toolbox_h = $("#toolbox_spacer_top").outerHeight() + $("#toolbox_spacer_bottom").outerHeight() + $("#toolbox").outerHeight();
    return topmargin_h + toolbox_h;
};

function toggle_detailbox(event){
    $('#detailbox').toggle();
    $('#notesbox').toggle();
    return false;
};

function show_detailbox(type, oid, ypos, toggled, callback){
    var dboxarea = $('#detailboxarea');
    dboxarea.load('/ybz/' + type + '/' + oid + '.ajax?t=' + (new Date()).getTime(), null, function(){replace_detailbox(ypos, toggled, callback);});
};

function reload_detailbox(callback){
    var oid = $('#detailbox > .identity').children("input[name='oid']").val();
    var type = $('#detailbox > .identity').children("input[name='type']").val();
    var ypos = $('#detailbox').css("top");
    var toggled = false;
    if ($('#notesbox').size() > 0 && "none" != $('#notesbox').css("display")) {
        toggled = true;
    }
    show_detailbox(type, oid, ypos, toggled, callback);
};

function replace_detailbox(ypos, toggled, callback){
    if (ypos == null) {
        ypos = 0;
    }
    var dbox = $('#detailbox');
    var nbox = $('#notesbox');

    if (ypos + dbox.outerHeight() > $('#detailboxarea').innerHeight()) {
        ypos = $('#detailboxarea').innerHeight() - dbox.outerHeight();
    }
    if (ypos < $('#selectionbox').outerHeight() + 10) {
        ypos = $('#selectionbox').outerHeight() + 10;
    }
    dbox.css("top", ypos);
    nbox.css("top", ypos);
    if (toggled) {
        dbox.hide();
        nbox.show();
    }
    else {
        dbox.show();
        nbox.hide();
    };
    $('#boxtoggle_notes').unbind().click(toggle_detailbox);
    $('#boxtoggle_main').unbind().click(toggle_detailbox);

    bind_events_detailbox();
    if (callback) { callback(); }
};

function clone_cloneable_item(event){
    var sibling_last = $('div.cloneable,div.cloneableline').eq($('div.cloneable,div.cloneableline').size() - 1);
    var cloned_from = $(event.target).closest('div.cloneable,div.cloneableline');
    var cloned_from_id = cloned_from.find('input.cloneable_number').val();
    var cloned_to = cloned_from.clone(true);
    var cloned_to_id = parseInt(sibling_last.find('input.cloneable_number').val()) + 1;
    cloned_from.find('select').each(function(){ // select.value is not cloned in $().clone, so set by hand.
        cloned_to.find('select').filter('[name="' + $(this).attr('name') + '"]').val($(this).val());
    });
    cloned_to.find('select,input').each(function(){ // replace name of input/select tags (value is cloneed above)
        $(this).attr('name', $(this).attr('name').replace(cloned_from_id, cloned_to_id));
    });
    cloned_to.find('input.cloneable_number').val(cloned_to_id);
    cloned_to.find('input.blank_onclone').val('');
    cloned_to.insertAfter(sibling_last);
};

function commit_mainview_form(form, success_message, on_success_callback, on_error_callback) {
    $(form).ajaxSubmit({
        success: function(data, datatype){show_success_dialog(success_message, data, on_success_callback);},
        error: function(xhr){show_error_dialog(xhr.responseText, on_error_callback);}
    });
    return false;
};

function commit_smartadd_form(event) {
    $(event.target).ajaxSubmit({
        success: reload_page,
        error: function(xhr){show_error_dialog(xhr.responseText);}
    });
    event.preventDefault();
    return false;
};

function commit_field_change(event) {
    var form = $(event.target).closest('form.field_edit_form');
    commit_field_form(form, function(){form.find('div.dataedit').find(':input').filter(':visible').focus();});
    event.preventDefault();
    return false;
};

function commit_order_change(event) {
    var swapfrom_valueitem = $(event.target).closest('li.valueitem');
    var swapfrom = swapfrom_valueitem.children('div.dataedit').children('input');
    var swapto_valueitem = null;
    if ($(event.target).attr('name') == 'up') {
        swapto_valueitem = swapfrom_valueitem.prev();
    }
    else {
        swapto_valueitem = swapfrom_valueitem.next();
    }
    var swapto = swapto_valueitem.children('div.dataedit').children('input');

    var tmp = swapfrom.val();
    swapfrom.val(swapto.val());
    swapto.val(tmp);
    
    commit_field_form($(event.target).closest('form.field_edit_form'), reload_detailbox);
    event.preventDefault();
    return false;
};

function commit_field_form(form, on_error_callback) {
    var fieldname = $(form).children("input[name='field']").val();
    var type = $('#detailbox > .identity').children("input[name='type']").val();
    var oid = $('#detailbox > .identity').children("input[name='oid']").val();
    $(form).ajaxSubmit({
        success: function(){reload_detailbox(function(){reload_table_rows(type, [oid]);});},
        error: function(xhr){show_error_dialog(xhr.responseText, on_error_callback);}
    });
    return false;
};

function commit_toggle_form(event) {
    var type = $('#detailbox > .identity').children("input[name='type']").val();
    var oid = $('#detailbox > .identity').children("input[name='oid']").val();
    $(event.target).ajaxSubmit({
        success: function(){reload_detailbox(function(){reload_table_rows(type, [oid]);});},
        error: function(xhr){show_error_dialog(xhr.responseText);}
    });
    event.preventDefault();
    return false;
};

function highlight_editable_item(event) {
    var target = $(event.target).closest('.clickableitem').children('div.dataview');
    target.addClass('dataviewhighlighted');

    target.children('div.dataeditbutton')
        .css('display', 'inline')
        .children('img.clickablebutton').unbind().click(show_editable_item);

    if (target.closest('.valueslist').find('input').filter(':visible').size() < 1) {
        target.siblings('div.dataupdown').css('display', 'inline');
        target.siblings('div.dataupdown').children('img.orderedit').unbind().click(commit_order_change);
    }
};

function un_highlight_editable_item(event) {
    var target = $(event.target).closest('.clickableitem').children('div.dataview');
    target.removeClass('dataviewhighlighted');
    target.children('div.dataeditbutton').hide();
    target.siblings('div.dataupdown').hide();
};

function show_editable_item(event) {
    var group = $(event.target).closest('.clickableitem,.memoitem');
    group.children('.dataview').hide();
    group.children('.dataedit').css('display', 'inline');
    group.children('.dataupdown').hide();

    if (group.children('.dataedit.combobox,.dataedit.selector').size() > 0) {
        /* combo box or selector setup */
        var box = group.children('.dataedit.combobox,.dataedit.selector');
        box.children('div.comboinput').hide();
        box.children('div.comboselect,div.selectorbox').children('select')
            .unbind()
            .blur(rollback_selectable_item)
            .blur(rollback_editable_item)
            .change(change_selectable_item)
            .focus();
    }
    else if (group.children('.dataedit.memoarea').size() > 0) {
        /* textarea memo setup */
        var inputarea = group.children('.dataedit').children('textarea');
        inputarea.addClass('datainput')
            .unbind()
            .focus(function(){this.select()})
            .focus();
        group.children('.dataedit').children('input[name="memoupdate"]')
            .click(function(e){$(e.target).closest('form.field_edit_form').submit(); return false;});
        group.children('.dataedit').children('input[name="memocancel"]')
            .click(rollback_editable_area);
    }
    else {
        /* normal ajax input text setup */
        var inputbox = group.children('.dataedit').children('input');
        inputbox.addClass('datainput')
            .unbind()
            .focus(function(){this.select()})
            .blur(rollback_editable_item)
            .keypress(function(e){if(e.which == 13){$(e.target).closest('form.field_edit_form').submit();};})
            .focus();
    }

};

function rollback_selectable_item(event) {
    var pre_val = $(event.target).closest('.clickableitem').children('.dataview').attr('title');
    var selectable = $(event.target).closest('.dataedit').children('.div.comboselect').children('select');
    if (pre_val == '') { selectable.val('___blank'); }
    else { selectable.val(pre_val); }
};

function rollback_editable_area(event) {
    var group = $(event.target).closest('.memoitem');
    group.children('div.dataedit').find('textarea[name="value"]').val(group.find('textarea.valueholder').val());
    group.children('.dataedit').hide();
    group.children('.dataview').show();
};

function rollback_editable_item(event) {
    var group = $(event.target).closest('.clickableitem');
    group.children('div.dataedit').find("input[name='value']").val(group.children('.dataview').attr('title'));
    group.children('.dataedit').hide();
    group.children('.dataview').show();
};

function show_add_item(event) {
    var div1 = $(event.target).closest('div.field').siblings('ul.valueslist').children('li.addinput');
    var div2 = div1.children('div');
    div1.show();
    div2.show();

    div2.children('input')
        .addClass('datainput')
        .unbind()
        .focus(function(){this.select();})
        .blur(hide_add_item)
        .keypress(function(e){if(e.which == 13){$(e.target).closest('form.field_edit_form').submit();};})
        .focus();
};

function hide_add_item(event) {
    var target = $(event.target).closest('li.addinput');
    $(event.target).val('');
    target.hide();
};

function change_selectable_item(event) {
    var selected_val = $(event.target).val();
    if (selected_val == '___blank') {
        return false;
    }
    else if (selected_val == '___input') {
        $(event.target).unbind();
        switch_combobox_input(event);
    }
    else {
        $(event.target).closest('.dataedit').find("input[name='value']").val(selected_val);
        commit_field_change(event);
    }
};

function switch_combobox_input(event) {
    var dataedit = $(event.target).closest('.combobox');
    dataedit.children('div.comboselect').hide();
    dataedit.children('div.comboinput').show();
    dataedit.children('div.comboinput').children('input')
        .addClass('datainput')
        .unbind()
        .focus(function(){this.select();})
        .blur(rollback_selectable_item)
        .blur(rollback_editable_item)
        .keypress(function(e){if(e.which == 13){$(e.target).closest('form.field_edit_form').submit();};})
        .focus();
};
