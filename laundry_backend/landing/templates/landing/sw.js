// Service Worker for Sparkles Receipts PWA

self.addEventListener('push', function(event) {
    if (!event.data) {
        console.log('Push event received with no payload');
        return;
    }
    
    try {
        const payload = event.data.json();
        const title = payload.title || 'Sparkles Notification';
        const options = {
            body: payload.body || 'Your order status has been updated.',
            icon: '/static/landing/images/logo.png', // Fallback icon path
            badge: '/static/landing/images/logo.png',
            data: {
                url: payload.url || '/'
            },
            vibrate: [100, 50, 100],
            actions: [
                {
                    action: 'open',
                    title: 'View Details'
                }
            ]
        };
        
        event.waitUntil(
            self.registration.showNotification(title, options)
        );
    } catch (e) {
        console.error('Error parsing push event payload:', e);
    }
});

self.addEventListener('notificationclick', function(event) {
    event.notification.close();
    
    // Default URL or fallback
    let clickUrl = '/';
    if (event.notification.data && event.notification.data.url) {
        clickUrl = event.notification.data.url;
    }
    
    // Open or focus window
    event.waitUntil(
        clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(windowClients) {
            // Check if there is already a window open with this URL
            for (let i = 0; i < windowClients.length; i++) {
                let client = windowClients[i];
                if (client.url === clickUrl && 'focus' in client) {
                    return client.focus();
                }
            }
            // If not, open a new window
            if (clients.openWindow) {
                return clients.openWindow(clickUrl);
            }
        })
    );
});
