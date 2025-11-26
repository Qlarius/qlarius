(function() {
  'use strict';

  // Guard to prevent multiple initializations
  if (window.tiqitArqadeInitialized) {
    console.log('[Tiqit Arqade] Already initialized, skipping');
    return;
  }
  window.tiqitArqadeInitialized = true;

  // Guard to prevent multiple activations
  let activationInProgress = false;

  function initTiqitArqadeWidget() {
    console.log('[Tiqit Arqade] Initializing widget...');
    const marker = document.getElementById('tiqit-paywall-hide-start');
    if (!marker) {
      console.warn('Tiqit Arqade: Marker div #tiqit-paywall-hide-start not found');
      return;
    }
    console.log('[Tiqit Arqade] Found marker div');

    const pieceId = marker.getAttribute('data-piece-id');
    if (!pieceId) {
      console.warn('Tiqit Arqade: data-piece-id attribute not found on marker div');
      return;
    }
    console.log('[Tiqit Arqade] Piece ID:', pieceId);

    const wrapper = marker.closest('.tiqit-paywall-story-wrap');
    if (!wrapper) {
      console.warn('Tiqit Arqade: Could not find .tiqit-paywall-story-wrap wrapper');
      return;
    }

    const paywallSection = wrapper.querySelector('.tiqit-paywall-section');
    if (!paywallSection) {
      console.warn('Tiqit Arqade: Could not find .tiqit-paywall-section');
      return;
    }

    const paywallContainer = paywallSection.querySelector('.paywall-container');
    if (!paywallContainer) {
      console.warn('Tiqit Arqade: Could not find .paywall-container');
      return;
    }

    const baseUrl = window.location.protocol + '//' + window.location.host;
    const iframeUrl = `${baseUrl}/widgets/arqade/${pieceId}?force_theme=light`;
    console.log('[Tiqit Arqade] Creating iframe with URL:', iframeUrl);

    const purchaseIframe = document.createElement('iframe');
    purchaseIframe.id = 'tiqit-arqade-purchase-iframe';
    purchaseIframe.src = iframeUrl;
    purchaseIframe.style.width = '100%';
    purchaseIframe.style.height = '720px';
    purchaseIframe.style.border = 'none';
    purchaseIframe.setAttribute('allow', 'fullscreen');

    paywallContainer.innerHTML = '';
    paywallContainer.appendChild(purchaseIframe);
    console.log('[Tiqit Arqade] Iframe injected successfully');

    window.addEventListener('message', function(event) {
      console.log('[Tiqit Arqade] Received postMessage:', event.data);
      console.log('[Tiqit Arqade] Message origin:', event.origin, 'Expected:', baseUrl);
      
      if (event.origin !== baseUrl) {
        console.warn('[Tiqit Arqade] Origin mismatch - ignoring message');
        return;
      }

      const data = event.data;
      console.log('[Tiqit Arqade] Message data:', data);
      
      if (data.type === 'tiqit_purchased' || data.type === 'tiqit_already_active') {
        if (activationInProgress) {
          console.warn('[Tiqit Arqade] Activation already in progress, ignoring duplicate message');
          return;
        }
        console.log('[Tiqit Arqade] Triggering activation for type:', data.type);
        activationInProgress = true;
        handleTiqitActivation(data, wrapper, paywallSection, baseUrl);
      } else {
        console.log('[Tiqit Arqade] Ignoring message type:', data.type);
      }
    });
  }

  function handleTiqitActivation(data, wrapper, paywallSection, baseUrl) {
    console.log('[Tiqit Arqade] Activating tiqit - removing paywall and revealing content');
    console.log('[Tiqit Arqade] Paywall section to remove:', paywallSection);
    
    // Find the marker first (before removing paywall section)
    const marker = document.getElementById('tiqit-paywall-hide-start');
    
    // Remove the paywall section (gradient + paywall container + iframe)
    if (paywallSection && paywallSection.parentNode) {
      paywallSection.parentNode.removeChild(paywallSection);
      console.log('[Tiqit Arqade] Paywall section removed successfully');
    } else {
      console.warn('[Tiqit Arqade] Could not remove paywall section - element not found or no parent');
    }
    
    // Double-check: remove any remaining purchase iframes
    const remainingPurchaseIframe = document.getElementById('tiqit-arqade-purchase-iframe');
    if (remainingPurchaseIframe) {
      remainingPurchaseIframe.remove();
      console.log('[Tiqit Arqade] Removed lingering purchase iframe');
    }
    
    // Reveal all content by removing height constraint and overflow hidden
    wrapper.style.height = 'auto';
    wrapper.style.overflow = 'visible';
    wrapper.style.opacity = '1';
    wrapper.style.filter = 'none';
    
    // Ensure all content after the marker is fully visible
    let elementsRevealed = 0;
    if (marker) {
      let currentElement = marker.nextElementSibling;
      while (currentElement) {
        // Skip the script tag
        if (currentElement.tagName !== 'SCRIPT') {
          currentElement.style.display = '';  // Reset to default display
          currentElement.style.opacity = '1';
          currentElement.style.visibility = 'visible';
          currentElement.style.filter = 'none';
          currentElement.style.color = '';  // Remove any color override
          elementsRevealed++;
        }
        currentElement = currentElement.nextElementSibling;
      }
    }
    
    console.log(`[Tiqit Arqade] Content revealed (${elementsRevealed} elements), injecting timer bar`);
    
    // Create and inject the timer bar iframe
    const timerSection = document.createElement('div');
    timerSection.className = 'tiqit-timer-section';
    timerSection.style.marginTop = '2rem';
    
    const timerIframe = document.createElement('iframe');
    timerIframe.id = 'tiqit-arqade-timer-iframe';
    timerIframe.src = `${baseUrl}/widgets/arqade/${data.piece_id}?force_theme=light`;
    timerIframe.style.width = '100%';
    timerIframe.style.height = '80px';
    timerIframe.style.border = 'none';
    timerIframe.setAttribute('scrolling', 'no');
    
    timerSection.appendChild(timerIframe);
    
    // Insert timer bar after the marker
    if (marker && marker.parentNode) {
      marker.parentNode.insertBefore(timerSection, marker.nextSibling);
    } else {
      // Fallback: append to wrapper
      wrapper.appendChild(timerSection);
    }
    
    console.log('[Tiqit Arqade] Timer bar injected successfully');
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initTiqitArqadeWidget);
  } else {
    initTiqitArqadeWidget();
  }
})();

