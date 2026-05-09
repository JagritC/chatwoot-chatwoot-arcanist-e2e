import { shallowMount } from '@vue/test-utils';
import ContactHeader from '../ContactHeader.vue';

describe('ContactHeader', () => {
  const mountComponent = () =>
    shallowMount(ContactHeader, {
      props: {
        headerTitle: 'Contacts',
      },
      global: {
        mocks: {
          $t: key => key,
        },
        stubs: {
          Button: true,
          Input: true,
          Icon: true,
          ContactSortMenu: true,
          ContactMoreActions: true,
          ComposeConversation: {
            template: '<div><slot name="trigger" /></div>',
          },
        },
      },
    });

  it('keeps the sticky contacts header above the selected contacts action bar', () => {
    const wrapper = mountComponent();

    expect(wrapper.find('header').classes()).toContain('z-20');
  });
});
