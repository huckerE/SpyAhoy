using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class LoadAnimScene : MonoBehaviour
{
    public void LoadNewScene()
    {
        StartCoroutine("WaitForSec");
       
        
    }
    IEnumerator WaitForSec()
    {
        yield return new WaitForSeconds(3);
        Cursor.lockState = CursorLockMode.None;
        Cursor.visible = true;
        UnityEngine.SceneManagement.SceneManager.LoadScene("Win Scene");

    }
}
