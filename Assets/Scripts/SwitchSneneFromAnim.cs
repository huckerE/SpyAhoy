using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

public class SwitchSneneFromAnim : MonoBehaviour
{
   public void ButtonClicked()
    {
        if (Input.GetKeyDown(KeyCode.E))
        {
            StartCoroutine(Delay());
        }
    }
    IEnumerator Delay()
    {
        yield return new WaitForSeconds(3f);
        SceneManager.LoadSceneAsync(7);
    }
}
