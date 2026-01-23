

let notificationTimer;

// Event listener for when the extension is installed or updated
chrome.runtime.onInstalled.addListener(() => {
  console.log("Extension installed or updated.");

  // Set the badge text to "8"
  chrome.action.setBadgeText({ text: '8' });
  console.log("Badge text set to '8'.");

  // Set the badge background color to red
  chrome.action.setBadgeBackgroundColor({ color: '#e36159' });
  chrome.action.setBadgeTextColor({ color: '#fff' });
  console.log("Badge background color set to red.");

  // preloadIframeContent();

  // Start the notification timer immediately upon first load
  startNotificationTimer();
  console.log("Notification timer started upon extension load.");
});

// Function to start the notification timer
function startNotificationTimer() {
  // Schedule the first notification after 6 seconds
  notificationTimer = setTimeout(() => {
    showNotification();
    console.log("First notification shown after 6 seconds.");

    // Schedule subsequent notifications every 30 minutes (1800 seconds)
    notificationTimer = setInterval(() => {
      showNotification();
      console.log("Notification shown every 30 minutes.");
    }, 1800000); // 1800000 milliseconds = 30 minutes
  }, 6000);
}

// Function to show a notification
function showNotification() {
  console.log("Showing notification.");

  // Create the notification
  chrome.notifications.create({
    type: 'basic',
    iconUrl: 'icon128.png',
    title: 'Sponster',
    message: 'Sponster here. You have 8 ads offering $1.73 in sponsorship. Click here to review.',
    priority: 2
  }, () => {
    console.log("Notification created.");
  });
}

// Event listener for when a notification is clicked
chrome.notifications.onClicked.addListener((notificationId) => {
  console.log("Notification clicked. Opening the extension popup.");

  // Open the extension popup by focusing on the current tab and triggering the popup
  chrome.action.openPopup();
});

function preloadIframeContent() {
  const iframe = document.createElement('iframe');
  iframe.src = 'https://qlarius.gigalixirapp.com/&in_frame=true&host_url=chrome_browser_extension';
  iframe.style.display = 'none'; // Hide the iframe
  document.body.appendChild(iframe);
  
  iframe.onload = () => {
    console.log('Iframe content preloaded.');
  };
}