using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

public class PauseMenu : MonoBehaviour
{

    public string firstlevel;

    public GameObject optionsScreen;
    // Start is called before the first frame update

    void Start()
    {
        UnlockMouse();
    }
    // Update is called once per frame
    void Update()
    {
        
    }

    void UnlockMouse()
    {
        Cursor.lockState = CursorLockMode.None;
        Cursor.visible = true;
    }
    public void ResumeGame()
    {
        SceneManager.LoadScene(2);
        //SceneManager.UnloadSceneAsync("Pause Menu",UnloadSceneOptions.UnloadAllEmbeddedSceneObjects);
    }

    public void OpenOptions()
    {
        optionsScreen.SetActive(true);
    }

    public void CloseOptions()
    {
        optionsScreen.SetActive(false);
    }

    public void MainMenu()
    {
        SceneManager.LoadScene(0);
    }
}
