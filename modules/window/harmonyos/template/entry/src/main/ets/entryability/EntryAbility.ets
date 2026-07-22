import UIAbility from '@ohos.app.ability.UIAbility';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import Want from '@ohos.app.ability.Want';
import hilog from '@ohos.hilog';
import window from '@ohos.window';
import windowHosted from 'libwindow_harmonyos_hosted.so';

const DOMAIN: number = 0x574E;
const TAG: string = 'WindowHosted';

export default class EntryAbility extends UIAbility {
  onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    windowHosted.hostOnStart();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (error) => {
      if (error.code) {
        hilog.error(DOMAIN, TAG, 'loadContent failed: %{public}s', JSON.stringify(error));
        return;
      }
      const started = windowHosted.startEventLoop();
      windowHosted.hostOnResume();
      hilog.info(DOMAIN, TAG, 'content loaded eventLoop=%{public}d', started ? 1 : 0);
    });
  }

  onForeground(): void {
    windowHosted.hostOnResume();
  }

  onBackground(): void {
    windowHosted.hostOnPause();
    windowHosted.hostOnStop();
  }

  onDestroy(): void {
    windowHosted.hostOnDestroy();
  }
}
