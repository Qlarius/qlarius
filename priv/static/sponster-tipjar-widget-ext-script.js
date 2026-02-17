var announcerDiv = document.getElementById("sponster-tipjar-announcer");
var widgetDiv = document.getElementById("sponster-tipjar-widget");
var splitCode = widgetDiv.getAttribute("sponster-split-code");
var hostURL = parent.document.URL

// Detect parent page theme based on common patterns
// var getParentTheme = function() {
//   var html = document.documentElement;
//   // Check for dark mode indicators
//   if (html.classList.contains('dark') || 
//       html.getAttribute('data-theme') === 'dark' ||
//       html.getAttribute('data-bs-theme') === 'dark' ||
//       window.matchMedia('(prefers-color-scheme: dark)').matches) {
//     return 'dark';
//   }
//   return 'light';
// };

// var theme = getParentTheme();

announcerDiv.setAttribute("style", "width:100%;position:fixed;bottom:0px;right:0;z-index:999999;height:80px;border-top-right-radius: 8px;border-top-left-radius: 8px;background: transparent;")
announcerDiv.innerHTML = `<iframe id='ydadget_sponster_announcer_iframe' src='../../widgets/ads_ext_announcer?split_code=${splitCode}&host_url=${hostURL}&force_theme=light' width='100%' height='80' frameBorder='0' allowtransparency='true' style='background: transparent !important;' />`;

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
    transform: translateX(-50%);
    width: min(100%, 800px);
    background-color: transparent;
    text-align: center;
    border-top-right-radius: 8px;
    border-top-left-radius: 8px;
    box-shadow: 0 -4px 20px rgba(0, 0, 0, 0.25);
    z-index: 999998;
    transition: bottom .5s ease-in-out, opacity .5s ease-in-out;
}
</style>`;

var widgetMarkup = 
`<div id='ydadget_sponster_adget_popover' style='opacity:0;visibility: hidden; backdrop-filter: blur(15px)' onclick='toggleSponster()'></div>
    <div id='ydadget_sponster_adget_popover_drawer' style='bottom:calc(-100vh - 10px);'>
        <iframe id='ydadget_sponster_adget_iframe' 
            width='100%' 
            style='height:90vh;border-top-right-radius: 8px;border-top-left-radius: 8px;background: transparent !important;' 
            frameBorder='0' 
            allowtransparency='true'
            src='../../widgets/ads_ext/${splitCode}?&in_frame=true&extension=true&host_url=${hostURL}&force_theme=light'
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

        var announcerIframe = document.getElementById('ydadget_sponster_announcer_iframe');
        if (announcerIframe && announcerIframe.contentWindow) {
            announcerIframe.contentWindow.postMessage('drawer_closed', '*');
        }

        // Add delay to allow animation to complete before refreshing iframes
        // setTimeout(() => {
        //     document.getElementById('ydadget_sponster_adget_iframe').src = document.getElementById('ydadget_sponster_adget_iframe').src;
        //     document.getElementById('ydadget_sponster_announcer_iframe').src = document.getElementById('ydadget_sponster_announcer_iframe').src;
        //     if (splitCode == 'youdata_main_app') {
        //         $.post('https://qlarius-app-staging-old-e240d7e2bcf7.herokuapp.com/sponster_ads/update_sponster_amounts');  
        //     }
        // }, 350);
    }
}