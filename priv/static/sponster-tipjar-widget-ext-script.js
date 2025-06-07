var announcerDiv = document.getElementById("sponster-tipjar-announcer");
var widgetDiv = document.getElementById("sponster-tipjar-widget");
var splitCode = widgetDiv.getAttribute("sponster-split-code");
var hostURL = parent.document.URL

announcerDiv.setAttribute("style", "width:100%;position:fixed;bottom:0px;right:0;z-index:999999;height:80px;border-top-right-radius: 8px;border-top-left-radius: 8px;")
announcerDiv.innerHTML = `<iframe id='ydadget_sponster_announcer_iframe' src='https://qlarius-app-staging-old-e240d7e2bcf7.herokuapp.com/ad_viewer_ext_announcer?split_code=${splitCode}&host_url=${hostURL}' width='100%' height='80' frameBorder='0' />`;

var sponsterWidgetCss = 
`<style>
#ydadget_sponster_adget_popover {
    position: fixed;
    left: 0px;
    top: 0px;
    width: 100%;
    height: 100%;
    text-align: center;
    z-index: 999998;
    background-color: rgba(0,0,0,0.8);
    -webkit-transition: all .5s ease-in-out;
    -moz-transition: all .5s ease-in-out;
    -o-transition: all .5s ease-in-out;
    -ms-transition: all .5s ease-in-out;
    transition: all .5s ease-in-out;
}
#ydadget_sponster_adget_popover_drawer {
    position: fixed;
    left: 50%;
    width: 800px;
    margin-left: -400px;
    background-color: #fff;
    border: 1px solid #000;
    text-align: center;
    border-top-right-radius: 8px;
    border-top-left-radius: 8px;
    -webkit-box-shadow: 0px 0px 6px 6px rgba(0,0,0,0.3);
    -moz-box-shadow: 0px 0px 6px 6px rgba(0,0,0,0.3);
    box-shadow: 0px 0px 6px 6px rgba(0,0,0,0.3);
    z-index: 999998;
    -webkit-transition: all .5s ease-in-out;
    -moz-transition: all .5s ease-in-out;
    -o-transition: all .5s ease-in-out;
    -ms-transition: all .5s ease-in-out;
    transition: all .5s ease-in-out;
}
#ydadget_sponster_adget_popover a.modalCloseImg {
    background: url('https://s3.amazonaws.com/youdata_sponster_adgets/CloseX.png') no-repeat;
    background-size: 20px;
    width: 20px;
    height: 20px;
    display: inline;
    z-index: 999999;
    position: absolute;
    top: -30px;
    cursor: pointer;
}
@media(max-width: 800px){
    #ydadget_sponster_adget_popover_drawer {
        width: 370px;
        margin-left: -185px;
    }
}
</style>`;

var widgetMarkup = 
`<div id='ydadget_sponster_adget_popover' style='opacity:0;visibility: hidden' onclick='toggleSponster()'></div>
    <div id='ydadget_sponster_adget_popover_drawer' style='bottom:calc(-100vh - 10px);border-top-right-radius: 8px;border-top-left-radius: 8px;'>
        <div onclick='toggleSponster()' style="width: 32px; height: 32px; margin:auto; top: -15px; right: -15px; position: absolute; background: #37373C; border-radius: 9999px; border: 1px solid #fff; cursor: pointer;">
            <div style="width: 100%; height: 100%; display: flex; justify-content: center; align-items: center;">
                <svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <g id="x 1">
                        <path id="Vector" d="M15 5L5 15" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                        <path id="Vector_2" d="M5 5L15 15" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                    </g>
                </svg>
            </div>
        </div>
        <iframe id='ydadget_sponster_adget_iframe' 
            width='100%' 
            style='height:90vh;border-top-right-radius: 8px;border-top-left-radius: 8px;' 
            frameBorder='0' 
            src='http://localhost:4000/widgets/ads_ext/${splitCode}?&in_frame=true&host_url=${hostURL}'
        />
    </div>
`
widgetDiv.innerHTML = sponsterWidgetCss + widgetMarkup;
    
//popover scripts
var eventMethod = window.addEventListener ? "addEventListener" : "attachEvent";
var messageEvent = eventMethod == "attachEvent" ? "onmessage" : "message";
window[eventMethod](messageEvent, function(e) {
    if ((e.data == 'open_widget') || (e.data == 'close_widget')) {
        toggleSponster();
    } else if (e.data == 'update_offer_count') {
        $.get('https://qlarius-app-staging-old-e240d7e2bcf7.herokuapp.com/sponster_adget_frames/refresh_offer_counts');  
    }
}, false);

function toggleSponster() {
    var popoverDiv = document.getElementById("ydadget_sponster_adget_popover");
    var popoverFrameDiv = document.getElementById("ydadget_sponster_adget_popover_drawer");
    if (popoverDiv.style.visibility == "hidden") {
        popoverDiv.style.visibility = "visible";
        popoverDiv.style.opacity = "1.0";
        popoverFrameDiv.style.bottom="48px";
    } else {
        popoverDiv.style.opacity = "0";
        popoverDiv.style.visibility = "hidden";
        popoverFrameDiv.style.bottom = "calc(-100vh - 10px)";
        
        // Add delay to allow animation to complete before refreshing iframes
        setTimeout(() => {
            document.getElementById('ydadget_sponster_adget_iframe').src = document.getElementById('ydadget_sponster_adget_iframe').src;
            document.getElementById('ydadget_sponster_announcer_iframe').src = document.getElementById('ydadget_sponster_announcer_iframe').src;
            if (splitCode == 'youdata_main_app') {
                $.post('https://qlarius-app-staging-old-e240d7e2bcf7.herokuapp.com/sponster_ads/update_sponster_amounts');  
            }
        }, 350);
    }
}