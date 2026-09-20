module.exports = () => ({
  email: {
    config: {
      provider: 'sendmail',
      providerOptions: {
        devHost: 'mailhog',
        devPort: 1025,
      },
      settings: {
        defaultFrom: 'Strapi Demo <no-reply@demo.local>',
        defaultReplyTo: 'Strapi Demo <no-reply@demo.local>',
      },
    },
  },
});