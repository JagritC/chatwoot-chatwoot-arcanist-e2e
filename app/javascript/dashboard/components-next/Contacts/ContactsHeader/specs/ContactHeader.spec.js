import { shallowMount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';

import ContactHeader from '../ContactHeader.vue';

describe('ContactHeader', () => {
  it('renders above sticky selected contact actions', () => {
    const wrapper = shallowMount(ContactHeader, {
      props: {
        headerTitle: 'Contacts',
      },
      global: {
        mocks: {
          $t: key => key,
        },
        stubs: {
          ComposeConversation: {
            template: '<div><slot name="trigger" /></div>',
          },
        },
      },
    });

    expect(wrapper.find('header').classes()).toContain('z-20');
  });
});
